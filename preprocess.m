
fclose('all'); clear; clc
expFolder = '/Volumes/ConnorHome/Julie/IntanData/Cortana/2023-09-15/'; %base path to experiment folder
expName = '1694801146439198_230915_140547';
animalID = 'mdemo'; unitID = '000'; expID = '000'; probeID = 1;
name = 'AC'; copyToZ = 0; MUflag = 0; legacyFlag = 0;  parts = 100;

parfor JobID = 0:parts-1
    extractSpikes(expFolder,expName,animalID,unitID,expID,probeID,name,copyToZ,MUflag,legacyFlag,parts,JobID);
end

parfor jobID = 0:parts-1
    extractSpikeProps(expFolder,animalID,unitID,expID,probeID,name,copyToZ,MUflag,jobID);
end