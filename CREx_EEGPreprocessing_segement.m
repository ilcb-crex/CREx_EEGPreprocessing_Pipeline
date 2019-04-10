function CREx_EEGPreprocessing_segement(Trigfile_path)
%% Date: 08-04-2019    Programmed by: D. Bolger
% Function to segment continuous data.
% The function allows you to load the data to be segmented manually. 
% Input: Trigfile_path ==> path to configuration structure resuming the trigger names and
% codes.
%**************************************************************************
%% ALLOW USER TO CHOOSE *.SET FILE

[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
[ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
EEG = pop_loadset();

[ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(EEG.setname),'gui','off'); % current set = xx;
EEG = eeg_checkset( EEG );
EEG = pop_saveset( EEG, 'filename',char(EEG.setname),'filepath',EEG.filepath); 
eeglab redraw

%% GET THE TRIGGER NAMES

cfgin = load(Trigfile_path);
fn = fieldnames(cfgin);
cfg = cfgin.(genvarname(fn{1,1}));

Conds_all = cfg.condgroups;    %each column corresponds to a group.
Group_all = cfg.groupnames;
Conds_all = reshape(Conds_all,[cfg.condnum 1]);

ln = listdlg('PromptString','Select one or several conditions','SelectionMode','multiple','ListString',Conds_all);
conds2seg = Conds_all(ln,1);
time_lim = inputdlg({'Enter trial upper limit (s)','Enter baseline upper limit (s)','Enter baseline lower limit (s)'},'Enter time limits',...
    [1 50;1 50;1 50]);

lim_upper = str2double(time_lim{1,1});
limbl_low = str2double(time_lim{3,1});
limbl_up_upper = str2double(time_lim{2,1});

dir_save = cfg.saveepoched;


for counter = 1:length(ALLEEG)
    
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'retrieve',counter,'study',0);
    EEG = eeg_checkset( EEG );
    eeglab redraw
    
    allconds_name = strcat(ALLEEG(counter).setname(1:8),'allconds');
    EEG = pop_epoch(EEG,Conds_all, [limbl_low lim_upper], 'newname', char(allconds_name), 'epochinfo', 'yes');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(allconds_name),'gui','off');
    EEG = eeg_checkset( EEG );
    EEG = pop_saveset( EEG, 'filename',char(allconds_name),'filepath',dir_save);
    EEG = eeg_checkset( EEG );
    eeglab redraw; 
     
    for condcnt = 1:length(conds2seg)
        
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'retrieve',counter,'study',0);
        EEG = eeg_checkset( EEG );
        eeglab redraw
        
        condcurr_name = strcat(ALLEEG(counter).setname(1:8),conds2seg{condcnt,1});
        EEG = pop_epoch( EEG, {conds2seg{condcnt,1}}, [limbl_low lim_upper], 'newname', char(condcurr_name), 'epochinfo', 'yes');
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(condcurr_name),'gui','off');
        EEG = eeg_checkset( EEG );
        EEG = pop_saveset( EEG, 'filename',char(condcurr_name),'filepath',dir_save);
        EEG = eeg_checkset( EEG );
        eeglab redraw; 
    
    end

end

