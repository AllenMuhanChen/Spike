
fclose('all'); clear; clc
expFolder = '/home/r2_allen/Documents'; %base path to experiment folder
animalID = 'mdemo'; unitID = '000'; expID = '000'; probeID = 1;
name = 'AC'; copyToZ = 0; MUflag = 0; legacyFlag = 0;  parts = 100;

parfor JobID = 0:parts-1
    extractSpikes(expFolder,animalID,unitID,expID,probeID,name,copyToZ,MUflag,legacyFlag,parts,JobID);
end

parfor jobID = 0:parts-1
    extractSpikeProps(expFolder,animalID,unitID,expID,probeID,name,copyToZ,MUflag,jobID);
end