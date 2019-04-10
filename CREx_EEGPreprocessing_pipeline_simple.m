
function CREx_EEGPreprocessing_pipeline_simple(paramfile_path,Trigcfg)


    %% OPEN THE PARAMETERS FILE WITH PRE-PROCESSING PARAMETERS.
    % Load the pre-processing parameters and project-specific paths defined in the parameters *.txt
    % file into the current workspace. 

    
    fid2 = fopen(paramfile_path);      % il faut changer le chemin
    mydata = textscan(fid2,'%s %s');

    for i = 1:length(mydata{1,1})                     % generate a parameters structure from the parameters text file
        Params.(genvarname(mydata{1,1}{i})) = mydata{1,2}(i);
    end

    % Get the project-specific paths
    DIR_main = char(Params.DIR_main);
    DIR_save = char(Params.DIR_save);
    chanloc_path = char(Params.chanloc_path);
    chandir = char(Params.chandir);
    trigpath = char(Params.triginfo);
    [fpath_trig,fnomtrig,trigext] = fileparts(trigpath);


    % Get preprocessing parameters
    f_low = str2double(Params.fc_low);
    f_hi= str2double(Params.fc_hi);
    SR_orig = str2double(Params.srate_orig);
    SR = str2double(Params.srate); 
    trialwind_lims = [str2double(Params.wind_low) str2double(Params.wind_hi)];
    baselims = [str2double(Params.blc_low) str2double(Params.blc_hi)];
    refs = [str2double(Params.references1) str2double(Params.references2)];


    %% FIND THE FILES THAT WE WISH TO PROCESS 

    allfiles= dir(DIR_main);
    fileIndex = find(~[allfiles.isdir]);
    filenum=dir(strcat(DIR_main,'*.bdf'));                      %find all the *.bdf files in the current folder
    filenom={filenum.name};


    %% LOOP THROUGH EACH SUBJECT 

    for counter = 1:4 %length(filenum)  
        %% OPEN EEGLAB SESSION
        % Opens an EEGLAB session and presents main EEGLAB GUI. 

        [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
        [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

        % LOAD IN THE *.bdf FILE OF THE CURRENT SUBJECT
        % Loads in the *.bdf file, ensuring that 74 channels are included so that the 
        % ERGO1 and ERGO2 data are loaded.

        fullDir = strcat(DIR_main,filenom{1,counter});
        fnom = filenom{1,counter}(1:end-4);

         %% CREATE A FOLDER FOR CURRENT SUBJECT IN WHICH TO SAVE PREPROCESSED DATA

        [status,error] = mkdir(DIR_save,fnom);
        DIRsave_curr = fullfile(DIR_save,fnom,filesep);

        %% The following three lines is added to resolve a bug occurring when
        % opening the *.bdf file.

        x = fileparts( which('sopen') );
        rmpath(x);
        addpath(x,'-begin');

        % Opening up *.bdf file and saving as a *.set file.
        EEG = pop_biosig(fullDir, 'channels',[1:72], 'ref', [] ,'refoptions',{'keepref' 'off'} );
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(fnom),'gui','off'); % Create a new dataset for the current raw datafile
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
        EEG = eeg_checkset( EEG );
        EEG = pop_saveset( EEG, 'filename',char(fnom),'filepath',DIRsave_curr);  % Saves a copy of the current resampled dataset to the current directory
        eeglab redraw


        %% ADD CHANNEL INFORMATION TO THE CURRENT DATASET.
        % Channel coordinates and labels are added to the current dataset and
        % the dataset is saved to the current subject-level directory. 
        % The Chaninfo.mat file is loaded as it contains the electrode labels. 
        % From EEGLAB plugins, the file, "standard-10-5-cap385.elp" is loaded
        % as this contains the correct coordinates for the 10-20 system used here. 

        chaninfo = load(chandir,'chaninfo');
        chans = chaninfo.chaninfo;

        for cnt = 1:length(chans)
            EEG.chanlocs(cnt).labels = chans(cnt).labels;
        end

        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
        EEG = eeg_checkset( EEG );

        EEG = pop_chanedit(EEG, 'lookup',chanloc_path);                % Load channel path information
        [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
        EEG = eeg_checkset( EEG );
        EEG = pop_saveset( EEG, 'filename',char(fnom),'filepath',DIRsave_curr);
        eeglab redraw

        %% PREPARE INFORMATION TEXT-FILE FOR THE CURRENT SUBJECT. 

        fname=strcat(fnom,'-info.txt');
        fdir=strcat(DIRsave_curr,fname);
        fid=fopen(fdir,'w');
        fprintf(fid,['---------',fnom,'----------\n']);

        %fprintf(fid,'The total number of trials is: %d\n',length(currconds{1,5}));

        %% RESAMPLE THE CONTINUOUS DATA USING THE PARAMETER DEFINED IN THE PARAMETERS TEXT FILE. 
        % Resamples using the EEG resampling function. 
        % If the user has the Matlab signal processing toolbox, it uses the
        % Matlab resample() function. 
        % Write information regarding the resampling to the subject-level text
        % file. 

        fprintf(fid,'\nDownsampled from %dHz to %dHz\n',SR_orig,SR);
        display('***********************************Resampling to 512Hz*******************************************')
        fnom_rs = strcat(fnom,'-rs');

        EEG = pop_resample(EEG, SR);   %resample the data at sampling rate defined, sr.
        EEG =eeg_checkset(EEG);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(fnom_rs),'gui','off'); % current set = xx;
        EEG = eeg_checkset( EEG );
        EEG = pop_saveset( EEG, 'filename',char(fnom_rs),'filepath',DIRsave_curr);  % Saves a copy of the current resampled dataset to the current directory
        eeglab redraw

        %% APPLY BAND-PASS FILTER BETWEEN THE LOWER AND UPPER LIMITS SPECIFIED IN PARAMETERS FILE.
        % It applies a FIR windowed sinc filter using a blackman filter.
        % The filter frequency response is plotted. 
        % The details of the filtering are written to subject information txt file.

        display('*********************************Bandpass filtering using a FIR windowed sinc filter***********************************')
        [M, dev] = pop_firwsord('blackman',SR, 2);
        [EEG,com,b] = pop_firws(EEG,'fcutoff',[f_low f_hi],'forder',M,'ftype','bandpass','wtype','blackman');
        fvtool(b);                                      % Visualise the filter characteristics
        fnom_filt = strcat(fnom_rs,'-filt');
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(fnom_filt),'gui','off');   %save the resampled data as a newdata set.
        EEG = eeg_checkset( EEG );
        EEG = pop_saveset( EEG, 'filename',char(fnom_filt),'filepath',DIRsave_curr);
        eeglab redraw

        fprintf(fid,'Band-pass filtered %f2 - %dHz with %d-order fir windowed sinc filter (blackman).\n',f_low,f_hi,M);

        %% VISUALISE THE REFERENCE AND THEIR SPECTRA CALCULATED USING MULTI-TAPERS.
        % Saves a figure of the spectra of the references to the current
        % folder (in the CREx_SpectCalc_multitap() function. 

        eegplot(EEG.data(refs,:),'srate',EEG.srate,'eloc_file',EEG.chanlocs(refs(1):refs(2)),'events',EEG.event,'color',{'g' 'b'},'dispchans',2,...
        'winlength',20,'title','Visualise reference electrodes (10sec per window)')

        specnom_ref = fullfile(DIRsave_curr,strcat(fnom_filt,'-spectref'));
        specnom_scalp = fullfile(DIRsave_curr,strcat(fnom_filt,'-spectscalp'));

        CREx_SpectCalc_multitap(EEG,65:66,[1 40],[],specnom_ref);
        CREx_SpectCalc_multitap(EEG,1:64,[1 40],[],specnom_scalp);


        %% RE-REFERENCE THE DATA TO THE ELECTRODES SPECIFIED IN THE PARAMETERS FILE.
        % The channels used for referencing are generally EXG1 and EXG2,
        % channels 65 and 66, respectively. 
        % The details of the re-referencing are written to the information text file. 

        display('***********************Rereference to Defined Channel:  does zero potential exist?*****************************')
        EEG = pop_reref(EEG, refs, 'method','standard','keepref','on');
        fnom_ref = strcat(fnom_filt,'-rref');
        EEG = eeg_checkset( EEG );
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',char(fnom_ref),'gui','off');   %save the resampled data as a newdata set.
        EEG = eeg_checkset( EEG );
        EEG = pop_saveset( EEG, 'filename',char(fnom_ref),'filepath',DIRsave_curr);
        EEG = eeg_checkset( EEG );
        eeglab redraw

        here = CURRENTSET;   % Mark the current set. 

        fprintf(fid,'Rereferenced using channels %s and %s.\n\n',EEG.chanlocs(refs(1)).labels,EEG.chanlocs(refs(2)).labels);

        %% DETECT POSSIBLE BAD ELECTRODES AUTOMATICALLY VIA EEGLAB KURTOSIS MEASURE.
        % Those electrodes with a kurtosis value >5 (z-score) are marked as
        % bad.
        % Bad electrodes electrodes detected with the measure are written to
        % the subject information text file.

        % Retrieve the dataset before the resting state. 
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'retrieve',here,'study',0);
        EEG = eeg_checkset( EEG );
        eeglab redraw

        chans = {EEG.chanlocs.labels};
        [EEG, eindx, measure,~] = pop_rejchan(EEG, 'elec',[1:72] ,'threshold',5,'norm','on','measure','kurt');
        EEG.reject.rejkurtE = eindx;                          %indices of suggested electrodes to reject according to kurtosis.

        if ~isempty(eindx)
            for cntr=1:length(eindx)
                if cntr==1
                    fprintf(fid,'Bad electrodes according to kurtosis (threshold z-score 5):  %s  ',chans{eindx(cntr)});
                elseif cntr>1 && cntr<length(eindx)
                    fprintf(fid,' %s  ',chans{eindx(cntr)});
                elseif cntr==length(eindx)
                    fprintf(fid,' %s \n ',chans{eindx(cntr)});
                end

            end
        else
            fprintf(fid,'No bad electrodes marked according to kurtosis (threshold z-score 5)\n');
        end

        here = CURRENTSET;

        %% RUN THE PREP PIPELINE FUNCTION TO AUTOMATICALLY DETECT NOISY CHANNELS, findNoisyChannels() 
        % Before running this function will need to take out the EXG channels that do not have X Y Z coordinates. 
        % This dataset is only used for the noisy channel detection script. 
        % This PREP function applies 4 different measures:
        % 1. Robust standard deviation (unusually high or low amplitude)
        % 2. Signal-to-Noise Ratio (SNR) (Christian Kothes, clean_channels()
        % function).
        % 3. Global correlation criteria (Nima Bigdely-Shamlo).
        % 4. RANSAC correlation (but may not always be performed).

        EEG = pop_select( EEG,'nochannel',{'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8'});
        EEG.setname = strcat(EEG.setname,'-remove-EXG');
        EEG = eeg_checkset( EEG );

        noisyOut = findNoisyChannels(EEG);   % Call of PREP pipeline function. 

        badchan_indx = noisyOut.noisyChannels.all;
        badchans = {chans{[badchan_indx]}};

        fprintf(fid,'Bad channels according to PREP pipeline noisy channel detector:\n');
        for i2 = 1:length(badchans)
            fprintf(fid,'%s\t',badchans{1,i2}); 
        end

        % Retrieve the original correct dataset before suppression of EXG channels. 
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'retrieve',here,'study',0);
        EEG = eeg_checkset( EEG );
        eeglab redraw

        %% NEED TO ADD A FUNCTION THAT FIXES THE TRIGGERS CODES IN THE EVENT FIELD OF THE CURRENT EEG STRUCTURE
        % Call of function here..

       events_all = [EEG.event.type];
       event_trignames = cell(length(events_all),1);

       for gcnt = 1:size(Trigcfg.condgroups,1)
           for ccnt = 1:size(Trigcfg.condgroups,2)
               cond_idx = find(events_all > Trigcfg.condtrigs_groups{gcnt,ccnt}(1) & events_all < Trigcfg.condtrigs_groups{gcnt,ccnt}(end));
               event_trignames(cond_idx) = deal(Trigcfg.condgroups(gcnt,ccnt));
           end
       end

       iblink = [events_all == Trigcfg.blink];
       event_trignames(iblink) = deal({'blink'});
       iyes = [events_all == Trigcfg.yes];
       event_trignames(iyes) = deal({'yes'});
       ino = [events_all == Trigcfg.no];
       event_trignames(ino) = deal({'no'});

       for tcnt = 1:length(events_all)
           EEG.event(tcnt).type = event_trignames{tcnt,1};
       end

        EEG = pop_saveset( EEG, 'filename',char(EEG.setname),'filepath',DIRsave_curr);
        EEG = eeg_checkset( EEG );
        eeglab redraw

    end

end % end of function 