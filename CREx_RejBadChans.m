%% SCRIPT TO REMOVE BAD ELECTRODES AND TO INTERPOLATE REMOVED ELECTRODES.
% Date: 28-05-2018                          Programmed by: Deirdre Bolger.
% This script allows the user to both remove noisy electrodes and to
% interpolate these electrodes using spherical spline interpolation.
% The bad electrode rejection and the interpolation can be carried out
% separately. 
% Note that for this interpolation script to work, the EEG data set must
% have the field EEG.chanlocs_prerej. This field contains the channel
% location information of all 72 electrodes. 
%
% Firstly, an EEGLAB session is opened and the user can choose the *.set
% file that they wish to process. 
% Pop up window to allow user to choose the electrodes that they wish to
% remove.
% The user can specify in the pop-up window if they wish to interpolate
% removed electrodes or not.
% If the user only wishes to carry out interpolation on the current
% dataset, they can leave the electrode section empty and specify 'Y' in
% the interpolation section. 
% 
%% ALLOW USER TO CHOOSE *.SET FILE
function CREx_RejBadChans()
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;                %open eeglab session
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

    EEG = pop_loadset();

    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(EEG.setname),'gui','off'); % current set = xx;
    EEG = eeg_checkset( EEG );
    EEG = pop_saveset( EEG, 'filename',char(EEG.setname),'filepath',EEG.filepath);  % Saves a copy of the current resampled dataset to the current directory
    eeglab redraw


    %% Define the folder in which to save the *.set after channel rejection.

    dirsave = EEG.filepath;

    if ~strcmp(dirsave(end),filesep)
        dirsave = fullfile(dirsave,filesep);
        EEG.filepath = dirsave;
    end

    %% Define graphical prompt.
    prompt={'Channels to reject: ', 'Spherical Spline Interpolation (Y/N):'};
    dlg_title ='Reject Channels';
    deflts ={'Fp1','N'};
    num_lignes=[10;3];
    chanrej_ans=inputdlg(prompt,dlg_title,num_lignes,deflts);
    options.resize='on';

    %% Look for the "-info.txt" file for the current subject and open it. 

    dir_open = dirsave;             %the directory of the current condition
    display(dir_open);                                   %display the contents of the current folder
    allfiles= dir(dir_open);
    fileIndex = find(~[allfiles.isdir]);
    filenum=dir(fullfile(dir_open,filesep,'*-info.txt'));
    fid=fopen(strcat(dir_open,filenum.name),'a');

    %% Run the following if electrodes have been specified for rejection.

    if ~isempty(chanrej_ans{1,1})     

    %% ADD INFORMATION REQUIRED FOR ELECTRODE REJECTION AND INTERPOLATION TO CURRENT EEG STRUCTURE.
    % Record the label and indices of the electrodes marked for rejection in
    % the EEG structure.

        EEG.rejchans = chanrej_ans{1,1};
        EEG.rejchan_indx = find(ismember({EEG.chanlocs.labels},chanrej_ans{1,1}));

    % Before removing any electrodes, extract the full channel location
    % information and save it to the EEG structure so it can be used for spherical spline
    % interpolation later.
    if ~isfield(EEG,'chanlocs_pre_rej')
        chanlocs_pre = EEG.chanlocs;
        EEG.chanlocs_prerej = chanlocs_pre;
    end

    %% Write to the "-info.txt" file of the current subject the channels marked for rejection.

    if ~isequal(fid,-1)
        fprintf(fid,' \n---------------------Channels Rejected---------------------\n');

        chanindx = zeros(size(chanrej_ans{1,1},1),1);   %for the channel indices
        for c=1:size(chanrej_ans{1,1},1)

            if c==size(chanrej_ans{1,1},1)
                fprintf(fid,'%s\n\n',chanrej_ans{1,1}(c,:));
                a=chanrej_ans{1,1}(c,:);
                chanindx(c)=find(strcmp({EEG.chanlocs.labels},cellstr(a)));
                clear a;
            elseif c<size(chanrej_ans{1,1},1)
                fprintf(fid,'%s\t',chanrej_ans{1,1}(c,:));
                a=chanrej_ans{1,1}(c,:);
                chanindx(c)=find(strcmp({EEG.chanlocs.labels},cellstr(a)));  %{EEG.chanlocs.labels}
            end
        end
    else
        chanindx = zeros(size(chanrej_ans{1,1},1),1); 

    end

    %% SAVE THE DATASET TO THE CURRENT DIRECTORY AFTER ELECTRODE REJECTION.

    if isempty(strfind(EEG.setname,'chanrej'))
        title_rej = strcat(EEG.setname,'-chanrej');
    else
        title_rej = EEG.setname;
    end
        EEG=pop_select(EEG,'nochannel',chanindx);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(title_rej),'gui','off'); % current set = xx;
        EEG = eeg_checkset( EEG );
        EEG = pop_saveset( EEG, 'filename',char(title_rej),'filepath',dirsave);  % Saves a copy of the current resampled dataset to the current directory
        eeglab redraw

    else
        disp('--------------------No electrodes for rejection specified--------------------------');
    end

    %% SPHERICAL SPLINE INTERPOLATION WAS SPECIFIED.
    % Note that for this interpolation script to work, the EEG data set must
    % have the field EEG.chanlocs_prerej. This field contains the channel
    % location information of all 72 electrodes. 


    if strcmp(chanrej_ans{2,1},'Y')==1
        disp('---------------------Carrying out Spherical Spline Interpolation on current dataset---------------------');

        spline_note='Carried out spherical spline interpolation';

        fprintf(fid,'%s\n\n',spline_note);
        fclose(fid);

        title_inter=strcat(EEG.setname,'-ssinterp');
        EEG = pop_interp(EEG,EEG.chanlocs_prerej, 'spherical');  % EEGLAB spherical spline interpolation function (eeg_interp())

         %[ALLEEG, EEG]=eeg_store(ALLEEG, EEG, CURRENTSET);
    %     [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(title_inter),'gui','off'); % current set = xx;
    % 
         EEG = pop_saveset( EEG, 'filename',char(title_inter),'filepath',dirsave);  % Saves a copy of the current resampled dataset to the current directory
    %     EEG = eeg_checkset( EEG );
    %     eeglab redraw

    else
        disp('***************No Interpolation for the moment***************************');
    end

end 