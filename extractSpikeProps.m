function extractSpikeProps(expFolder,animalID,unitID,expID,jobID,name)
% extract properties for spikes (one job file at a time)
% input parameters:
% animalID - animal ID (string)
% unitID - unit ID (string)
% expID - experiment ID (string)
% expFolder - base folder for experiments (string)
% jobID - job ID of raw spike file to process (number)
% name - name or initials of person running the script (for bookkeeping)
%
% output parameters:
% structure spk with fields (each is a vector/matrix with entries for each
% spike)
% - EnAll: Energy for detection plus surrounding channels
% - EnDet: Energy for detection channel only (also contained in EnAll, this
% is to speed up later computations that only need the detection channel)
% - AmpMinAll, AmpMinDet: Minimum amplitude 
% - AmxMaxAll, AmpMaxDet: Maximum amplitude
% - PksAll, PksDet: Max-Min
% - WidthAll, WidthDet: Time of max - time of min
% - chListAll: List of channels included
% - comXMinDet, comZMinDet: center of mass for x and z, based on minimum
% - comXEnDet,comZEnDet: center of mass for x and z, based on energy
% - comZMinDetShaft, comZEnDetShaft: center of mass for z, organized to
% split shafts (based on detection channel)
% - timesDet: spike times for detection channels
% - detCh: id of detection channel
% - detChSort: id of detection channel, sorted according to Z and shank
% - detProbe: id of detection probe
% - flagDuplicate: possible detection of one spike as separate events on
% different channels
%
% splits data into separate files for each probe
% also updates the id file


%we need the id file for probe settings
expname=[animalID '_u' unitID '_' expID];
load(fullfile(expFolder,animalID,expname,[expname '_id'])); %generates id

%compute total channel number
nChannels=sum([id.probes.nChannels]);

%parameter choices
spkWindow=[-4 6]; %determines over how many datapoints we're looking for the minimum


%open matfile with spike data 
%generates spikeData and settings
load(fullfile(expFolder,animalID,expname,'SpikeFiles',[expname '_j' num2str(jobID) '_spike'])); 
%samples per spike waveform
spikeSamples=settings.spikeSamples;

%% go through spike file, compute properties for each spike, collected in arrays


for p=1:length(id.probes)
    spkCount=1;
    spk=struct;
    
    %sort channels according to z and shank
    probeOrg=[id.probes(p).z id.probes(p).shaft id.probes(p).channels+1];
    probeSort=sortrows(probeOrg,[2 1]);
    
    %maximum z (for shaft separation)
    maxZ=max(id.probes(p).z);
    
    for i=1:id.probes(p).nChannels
        
        offsetCh=sum([id.probes(1:p-1).nChannels]); %0 for p=1
             
        %only go through channels that actually have spikes
        if length(spikeData(i+offsetCh).spikeTimes)>1 | ~isnan(spikeData(i+offsetCh).spikeTimes)
            
            %base parameters
            Nspikes=length(spikeData(i+offsetCh).spikeTimes);
            Nch=length(spikeData(i+offsetCh).channelIds);
            
            %compute energy: sum squares across time
            En=squeeze(sum(spikeData(i+offsetCh).Wvfrms.^2,2));
            if Nspikes==1 %need to flip the vector in this case
                En=En';
            end
            
            %compute minimum and maximum
            %we will base these on the derivative - we want a minimum
            %that is the local minimum around the minimum time at the
            %detection channel (for which the minimum will be at
            %spikeSamples+1), and a maximum that is the first maximum
            %after the positive going part of the waveform
            %both are more correctly detected based on the slope rather
            %than using min/max over a set interval
            %we can't use the minimum at the detection time point
            %because the minimum occurs at different time points on
            %different channels
            
            %sign of slope
            Wv1Der=sign(diff(spikeData(i+offsetCh).Wvfrms,1,2));
            
            %2nd derivative of the sign
            Wv2Der=diff(Wv1Der,1,2);
            
            %minimum: maximum in 2nd derivative around the spikeSamples+1
            %using +-5 data points for now
            [minDer,TimeMin]=max(Wv2Der(:,spikeSamples+spkWindow(1):spikeSamples+spkWindow(2),:),[],2);
            
            %because of how diff works, max of derivative is one ahead of true min, also
            %add time offset relative to original waveform
            TimeMin=squeeze(TimeMin)+spikeSamples+spkWindow(1); %spikes x channel
            
            %if there is no local minimum, use the minimum of the
            %detection channel
            TimeMin(squeeze(minDer)==0)=spikeSamples+1;
            
            %now get minimum values
            %need to turn TimeMin into the correct index first
            spkIdx=repmat([1:Nspikes]',1,Nch);
            chIdx=repmat([1:Nch],Nspikes,1);
            if Nspikes==1 %need to flip the time vector in this case
                TimeMin=TimeMin';
            end
            mxIdx=sub2ind([Nspikes 2*spikeSamples+1 Nch],spkIdx,TimeMin,chIdx);
            AmpMin=spikeData(i+offsetCh).Wvfrms(mxIdx); %spikes x channels
            
            %do the same for the maximum (minimum in 2nd derivative)
            %searching after occurence of the minimum for detection
            %channel
            %min automatically returns the index to the first occurence if
            %the minimum occurs more than once
            [~,TimeMax]=min(Wv2Der(:,spikeSamples+1:end,:),[],2);
            TimeMax=squeeze(TimeMax)+spikeSamples+1; %spikes x channel
            
            %now get maximum values
            if Nspikes==1 %need to flip the time vector in this case
                TimeMax=TimeMax';
            end
            mxIdx=sub2ind([Nspikes 2*spikeSamples+1 Nch],spkIdx,TimeMax,chIdx);
            AmpMax=spikeData(i+offsetCh).Wvfrms(mxIdx);
            
            %peak to peak value
            Pks = AmpMax-AmpMin;
            
            %width
            Width=TimeMax-TimeMin;
            
                       
            %compute center of mass using minimum and energy, using the coordinates of the
            %channels; we won't separate by shank here since every
            %channel has a unique position, so it's not necessary
            chId=spikeData(i+offsetCh).channelIds-offsetCh;
            xpos=id.probes(p).x(chId);
            zpos=id.probes(p).z(chId);
            
            comXMin=sum(abs(AmpMin).*xpos',2)./sum(abs(AmpMin),2);
            comZMin=sum(abs(AmpMin).*zpos',2)./sum(abs(AmpMin),2);
            
            comXEn=sum(En.*xpos',2)./sum(En,2);
            comZEn=sum(En.*zpos',2)./sum(En,2);
            
            comZEnShaft=comZEn+(maxZ+100)*(id.probes(p).shaft(i)-1); %buffer of 100um between shafts
            comZMinShaft=comZMin+(maxZ+100)*(id.probes(p).shaft(i)-1);
            
            %since we are reorganizing into a structure per spike,
            %there are a couple of things we need to copy from
            %spikeData
            %time stamps
            spkTimes=spikeData(i+offsetCh).spikeTimes;
            
            %detection channel - we need this twice (to get amplitudes
            %in sort gui)
            detChIdx=repmat(i,size(spkTimes));
            detChRaw=repmat(i+offsetCh,size(spkTimes));
            
            %detection probe
            %detProbeIdx=repmat(p,size(spkTimes));
            
            %detection channel sorted according to z
            detChIdxSort=find(probeSort(:,3)==i);
            detChIdxSort=repmat(detChIdxSort,size(spkTimes));
            
            %channel list
            chList=repmat(spikeData(i+offsetCh).channelIds',Nspikes,1);
            
            %output
            %entries with spikes x channels - for all of these, we also
            %save the detection channel separately
            spk.EnAll(spkCount:spkCount+Nspikes-1)=num2cell(En,2); %number of channels might change
            spk.EnDet(spkCount:spkCount+Nspikes-1)=En(:,1);
            
            spk.AmpMinAll(spkCount:spkCount+Nspikes-1)=num2cell(AmpMin,2); 
            spk.AmpMinDet(spkCount:spkCount+Nspikes-1)=AmpMin(:,1); 
            
            spk.AmpMaxAll(spkCount:spkCount+Nspikes-1)=num2cell(AmpMax,2);
            spk.AmpMaxDet(spkCount:spkCount+Nspikes-1)=AmpMax(:,1);
            
            spk.PksAll(spkCount:spkCount+Nspikes-1)=num2cell(Pks,2);
            spk.PksDet(spkCount:spkCount+Nspikes-1)=Pks(:,1);
            
            spk.WidthAll(spkCount:spkCount+Nspikes-1)=num2cell(Width,2); 
            spk.WidthDet(spkCount:spkCount+Nspikes-1)=Width(:,1); 
            
            spk.chListAll(spkCount:spkCount+Nspikes-1)=num2cell(chList,2);
            
            %entries wit spikes x 1
            spk.comXMinDet(spkCount:spkCount+Nspikes-1)=comXMin;
            spk.comZMinDet(spkCount:spkCount+Nspikes-1)=comZMin;
            spk.comZMinShaftDet(spkCount:spkCount+Nspikes-1)=comZMinShaft;
            spk.comXEnDet(spkCount:spkCount+Nspikes-1)=comXEn;
            spk.comZEnDet(spkCount:spkCount+Nspikes-1)=comZEn;
            spk.comZEnShaftDet(spkCount:spkCount+Nspikes-1)=comZEnShaft;
            spk.spkTimesDet(spkCount:spkCount+Nspikes-1)=spkTimes;
            spk.detCh(spkCount:spkCount+Nspikes-1)=detChIdx;
            spk.detChRaw(spkCount:spkCount+Nspikes-1)=detChRaw;
            spk.detChSort(spkCount:spkCount+Nspikes-1)=detChIdxSort;
            %spk.detProbe(spkCount:spkCount+Nspikes-1)=detProbeIdx;
            
            spkCount=spkCount+Nspikes;
            
            
        end %if no spikes
    end %for ch
    
    % now go through and flag potential duplicates - we do this at the spike
    %level (only flag events that are separately detected on multiple channels;
    %different from the amplitude extraction at neighboring channels
    %happening above)
    spk.flagDuplicate=zeros(size(spk.spkTimesDet));
    timesIdx=[1:length(spk.spkTimesDet)];

    for i=1:id.probes(p).nChannels
        
        %find spikes at detection channel, get their energy and position in
        %spkTimes vector
        detTimes=spk.spkTimesDet(spk.detCh==i);
        timesIdxDet=timesIdx(spk.detCh==i);
        enDet=spk.EnDet(spk.detCh==i);
       
        %spread out each event over neighboring samples (to give interval
        %for detection)
        detTimesConv=detTimes+[spkWindow(1):spkWindow(2)]'; 
        detTimesConv=detTimesConv(:);
        
        %also need an index for grouping later
        detIdxConv=repmat([1:length(detTimes)],spkWindow(2)-spkWindow(1)+1,1);
        detIdxConv=detIdxConv(:);
        
        %get the other channels
        chList=spikeData(i+offsetCh).channelIds-offsetCh; %since detCh is probe specific 
        chList=chList(2:end); %need to remove center channel
        
        %find overlapping events 
        tf=ismember(spk.detCh,chList) & ismember(spk.spkTimesDet,detTimesConv);
        
        %only continue if there actually are any
        if sum(tf)>0
            %get energy of overlapping events
            enCh=spk.EnDet(tf);
            
            %get their index in the spkTimesDet vector
            timesIdxCh=timesIdx(tf);
            
            %get index of original event to use as grouping par
            [~,locB]=ismember(spk.spkTimesDet(tf),detTimesConv);
            idxCh=detIdxConv(locB);
            
            %generate one big array for accumarray
            enAll=[enDet(unique(idxCh)) enCh]'; %we only want the relevant original spikes
            idxAll=[unique(idxCh);idxCh];
            timesIdxAll=[timesIdxDet(unique(idxCh)) timesIdxCh];
            
            %get maximum per group
            maxData=accumarray(idxAll,enAll,[],@max);
            
            %flag which of the overlapping events are not the maximum (i.e.
            %duplicates)
            flagD = enAll~=maxData(idxAll);
            
            %put back into large vector
            idxD=timesIdxAll(flagD);
            spk.flagDuplicate(idxD)=1; %set to zero outside loop; so events that get flagged multiple times are still ok
        end
    end %for ch
    
    %add expname just in case
    spk.expname=expname;
    spk.probeId=p;

    outname=fullfile(expFolder,animalID,expname,'SpikeFiles',[expname '_j' num2str(jobID) '_p' num2str(p) '_spkinfo']);
    save(outname,'spk','-v7.3');
    
end %for probes




%add to id file for job 0 for bookkeeping
if jobID==0
    id.extractSpikeProps.name=name;
    id.extractSpikeProps.date=date;
    save(fullfile(expFolder,animalID,expname,[expname '_id']),'id');
end


disp(['extractSpikes job ID ' num2str(jobID) ' done.'])



            
            
            
     
            
  