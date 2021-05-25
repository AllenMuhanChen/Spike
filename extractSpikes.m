function extractSpikes(animalID,unitID,expID,settings,parts,JobID)
% extractSpikes computes spike waveforms
% input parameters:
% animalID - animal ID (string)
% unitID - unit ID (string)
% expID - experiment ID (string)
% settings - structure with settings parameters
% parts - number of segments to divide the data file into
% JobID - current segment to process; starts with 0

% output (saved in matlab file)
% spikeData - structure with fields (one per detection channel)
%    spikeTimes - time of minimum at detection channel (in samples, not seconds)
%    channelIds - channels for which waveforms are extracted (within set
%    distance from detection channel); IDs are numbered as in acquisition
%    file, not according to location
%    rawWvfrms - raw waveforms at the selected channel in a window around
%    the timestamp in spikeTimes; spikes x time x channel
%    Wvfrms - same waveforms as in rawWvfrms, but baseline correct using
%    start of each waveform

% requires SpikeFiles directory to be present in the experiment folder
% also updates the id file
%% generate basic info
%load threshold and id data
expname=[animalID '_u' unitID '_' expID];
load(fullfile(settings.expFolder,animalID,expname,[expname settings.extThres])); %generates thresholding
load(fullfile(settings.expFolder,animalID,expname,[expname settings.extId])); %generates id

%compute total channel number
nChannels=sum([id.probes.nChannels]);

%get file size
filename=fullfile(settings.expFolder,animalID,expname,[expname settings.extData]);
fileinfo = dir(filename);
samples = fileinfo.bytes/(2*nChannels); % Number of samples in amplifier data file
samplesPerJob = ceil(samples/parts); % Number of samples to allocate to each of the 200 jobs
partsOverlapSamples = floor((2/1000)*id.sampleFreq); % get 2msec overlap between samples



%% read data
firstSample = samplesPerJob*JobID - partsOverlapSamples; % Sets first sample to process; each job has 1st 2msec overlap with previous job and last 2msec overlap with next job
if firstSample<0
    firstSample=0;
end

DataFile = fopen(filename,'r'); % Load amplifier data
fseek(DataFile,2*nChannels*firstSample,'bof'); % Offset from beginning of file

if JobID == parts-1 % The last job - first JobID is 0
    samplesLeft = samples - samplesPerJob*(parts-1) + partsOverlapSamples; % samplesLeft=TotalSamples-SamplesDone+Overhang
    Data = fread(DataFile, [nChannels samplesLeft], 'int16'); % If JobID is the last job, read all the samples left
else
    Data = fread(DataFile, [nChannels samplesPerJob], 'int16'); % If JobID isn't the last job, read samplesPerJob samples past the file position set by fseek
end

%transpose data - matlab is faster with the longer dimension as rows rather
%than columns
Data=Data';

% Filter and normalize to threshold
Data = filter(thresholding.butter.b1, thresholding.butter.a1, Data,[],1);

% set bad channels to NaN (could also remove them)
Data(:,logical(thresholding.badChannels))=NaN; %this propagates the choice to the output
numChs = sum(~thresholding.badChannels); % Number of good channels



%% implement artificial threshold across time
% this is implemented by spreading out minimum peaks of voltage across time and
% space (channels, see next part). we are keeping the minimum value in a sliding window of the refractory
%period length. the window extends forwards and backwards. effectively, this causes
%a 'timeout' period before and after each strong minimum, in which other smaller minima are erased

%this code is consistent with Augusto's version, with the exception of the
%first and last data points [settings for Augusto's code: shift [31 30]]
nTime=floor(settings.refrTime/1000*id.sampleFreq);
minData=movmin(Data,[nTime+1 nTime],1);


%% implement artificial threshold across space
%similar to the logic for the artifical threshold across time, this spreads
%out a minimum across channels
%the faster way would be to use movmin after sorting channels according to
%position; not used here because the movmin approach makes assumptions
%about regular spacing between probe sites that often are violated

%base code fragment for movmin
%for i=1:id.probes.nShanks
%    minTmp=minData(:,id.probes.config(id.probes.shaft==i));
%    minData(:,1+(i-1)*id.probes.nChannels/id.probes.nShanks:i*id.probes.nChannels/id.probes.nShanks)=movmin(minTmp,9,2);
%end

if settings.useRefrSpace
    %this should only be executed for the probes; we want to keep the signals
    %from tetrode wires independent
    if length(id.probes)>1 || ~strcmp(id.probes.type,'single') && ~strcmp(id.probes.type,'tetrode')
        
        minDataTmp=minData;
        
        for p=1:length(id.probes)
            for i=1:id.probes(p).nChannels
                
                offsetCh=sum([id.probes(1:p-1).nChannels]); %0 for p=1
                
                if ~thresholding.badChannels(i+offsetCh)
                    distCh=sqrt((id.probes(p).x-id.probes(p).x(i)).^2+(id.probes(p).z-id.probes(p).z(i)).^2);
                    mask=(distCh<=settings.refrSpace);
                    
                    maskFull=false(nChannels,1);
                    maskFull(offsetCh+1:offsetCh+length(mask),1)=mask;
                    
                    minData(:,i+offsetCh)=min(minDataTmp(:,maskFull),[],2);
                end
            end
        end
        
        clear minDataTmp;
    end
end


%% Detect threshold crossings within .3msec
%detect threshold crossings
AboveTh=Data>thresholding.thresholds';

%get the transition points from below to above threshold (negative
%circshift shifts backwards, so this marks the last 1 (above threshold)
%before a 0 (below threshold)
CrossTh = AboveTh & circshift(~AboveTh,[-1 0]); 

%expand the threshold crossing out to cover the refractory period
nCross=floor(settings.refrCross/1000*id.sampleFreq);
CrossTh = movmax(CrossTh,[nCross 0],1);


%% Make sure there is no repeated value of max during artificial refractory period (necessary for raw data with low bit depth)
%double - unlikely this will actually ever occur, so removed for now
% RepeatedMax = zeros(size(Data));
% % Is the first max in 15 samples across neighbor channels
% for ch = -8:8 % channel window
%     for sm = -30:0 % sample window
%         if ~(sm==0 && ch==0)
%         RepeatedMax = RepeatedMax | Data == circshift(Data,[sm ch]);
%         end
%     end
% end

%% Final spikes detection

%find spikes: Minimum across refrTime and refrSpace within refrCross after
%threshold crossing
%this sets the occurence of the minimum of a waveform to 1
Spikes = CrossTh & minData==Data; 

% Removes spikes detected in the first 1msec overlap at the beginning and end of each job. 
%This is important as some of these may go beyond recording to get waveform.
Spikes(1:floor(partsOverlapSamples/2),:)=0; 
Spikes(end-floor(partsOverlapSamples/2):end,:)=0; 


%% extract the actual waveforms

%output file - we're saving each job separately so that things can run in parallel
outname=fullfile(settings.expFolder,animalID,expname,'SpikeFiles',[expname '_j' num2str(JobID) settings.extSpike]); 
matOut=matfile(outname,'Writable',true);

%add settings and original file name for record keeping
matOut.settings=settings;
matOut.expname=expname;

for p=1:length(id.probes)
    for i=1:id.probes(p).nChannels
            
        offsetCh=sum([id.probes(1:p-1).nChannels]); %0 for p=1
        
        if ~thresholding.badChannels(i+offsetCh)
    
            %initialize output - we're collecting things in a structure here, to
            %add it to the matfile object later; we're only extracting spike
            %data here, rest will happen in next file to make it easier to add
            %new properties
            spikeData = struct;
            
            Times = find(Spikes(:,i+offsetCh)>0); % Find coordinates where spikes occurred
            spikeData.spikeTimes=Times+firstSample;
            
            Nspikes=length(Times);
            %continue only if there are spikes
            if Nspikes>0
                
                %extract waveforms - we are ignoring the shank here, since shanks might
                %be close enough to pick up the same waveforms
                %the number of channels in this radius will be variable across
                %channels, but should be very similar for neighboring channels and will
                %be constant for each channel
                %we're reorganizing things according to distance to the
                %detection channel, which also makes the detection channel
                %the first entry in the waveform matrices
                distCh=sqrt((id.probes(p).x-id.probes(p).x(i)).^2+(id.probes(p).z-id.probes(p).z(i)).^2);
                [distOrg,distIdx]=sort(distCh);                
                spikeData.channelIds=distIdx(distOrg<=settings.spikeRadius)+offsetCh; %add offset back to get to correct channels
                Nch=length(spikeData.channelIds);
                         
                wv=Data([-settings.spikeSamples:settings.spikeSamples]+Times,spikeData.channelIds);
            
                Ntime=2*settings.spikeSamples+1;
                spikeData.rawWvfrms=reshape(wv,[Nspikes Ntime Nch]); %dimensions: spike x timepoints x channel
        
                %normalize by baseline
                Nbase=floor(settings.spikeSamples/2);
                spikeData.Wvfrms=spikeData.rawWvfrms-mean(spikeData.rawWvfrms(:,1:Nbase,:),2);
                
                %save
                matOut.spikeData(1,i+offsetCh)=spikeData;
            else
                spikeData.spikeTimes=NaN;
                spikeData.channelIds=NaN;
                spikeData.rawWvfrms=NaN;
                spikeData.Wvfrms=NaN;
                matOut.spikeData(1,i+offsetCh)=spikeData;
                
            end
        end
    end
end

%for job 0, add info to id file for bookkeeping
if JobID==0
    id.extractSpikes.date=date;
    id.extractSpikes.name=settings.name;
   
    jobVec=[0:parts-1];
    startSample = samplesPerJob*jobVec - partsOverlapSamples; 
    startSample(startSample<0)=0;
    stopSample=startSample+samplesPerJob;
    stopSample(end)=samples;
    edgeSample=startSample+partsOverlapSamples/2; %boundaries between samples
    edgeSample(end+1)=samples; %to finish the last bin
    
    id.extractSpikes.jobStart=startSample;
    id.extractSpikes.jobStop=stopSample;
    id.extractSpikes.jobEdges=edgeSample;
    
    save(fullfile(settings.expFolder,animalID,expname,[expname settings.extId]),'id'); 
end

disp(['extractSpikes job ID ' num2str(JobID) ' done.'])

        

