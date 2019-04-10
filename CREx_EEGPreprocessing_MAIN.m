%% CREx_EEGPreprocessing_MAIN


%% SETUP CONFIGURATION STRUCTURE TO CONTAIN TRIGGER INFORMATION FOR CURRENT STUDY
DIRmain = fullfile(filesep,'Users','bolger','Documents','work','Projects','Project-L2-SentenceProc',filesep);

Tcfg = L2sent_make_trigstruct; 

%% CALL OF FUNCTION TO CARRY OUT EEG PREPROCESSING PIPELINE

paramfile_nom = 'L2sentence_parameters.txt';      %Name of parameters file
paramfile_path = fullfile(filesep,'Users','bolger','Documents','work','Projects','Project-L2-SentenceProc',paramfile_nom);   %full path to parameters file.

CREx_EEGPreprocessing_pipeline_simple(paramfile_path,Tcfg);        %Function call

%% CALL OF FUNCTION TO REJECT BAD ELECTRODES

CREx_RejBadChans();

%% CALL OF FUNCTION TO CARRY OUT ICA ON CONTINUOUS DATA

CREx_ICA_calc();

%% CALL OF FUNCTION TO SEGMENT THE CONTINUOUS DATA

trigfile_path = trigfile_mat;
CREx_EEGPreprocessing_segement(trigfile_path);

%% RUN FUNCTION TO LOCATE BAD EPOCHS AND CHANNELS VISUALLY.
% This works best on segmented data but can also work on continuous also,
% but can be very slow; 

EpochChan_dlg(EEG); 