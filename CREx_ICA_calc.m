%%Date: 09-04-2019 .     Programmed by: D. Bolger
% Function to carry out ICA on a selected EEG dataset.
% It also runs the ADJUST toolbox to assist the user in identifying ICA
% components that correspond to ocular and muscular artefacts.
%**************************************************************************
function CREx_ICA_calc()

    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;                %open eeglab session
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

    EEG = pop_loadset();   %Allows you to select and load the dataset manually.

    icalen=length(EEG.chanlocs)-8; % Do not take into account the external electrodes. 

    if size(EEG.data,3)>1       %If input data is epoched


        EEG_out = eeg_epoch2continuous(EEG); 

    elseif size(EEG.data,3)==1    %If input data is continuous 

        EEG_out = EEG;

    end

    %% CARRY OUT ICA USING THE RUNICA FUNCTION 


    display('--------------Carrying out ica: patience!--------------------');
    [weights, sphere,compvars,bias,signs,lrates,activations]=runica(EEG_out.data(1:icalen,:), 'extended',1);


    EEG_out.icaweights = weights;
    EEG_out.icasphere = sphere;
    EEG_out.icachansind = 1:icalen;
    EEG_out.icaact = activations; 
    icaprojdata = icaproj(EEG_out.data(1:icalen,:),weights,1:icalen);
    EEG_out.icawinv = inv(weights*sphere);

    %% SAVE THE DATASET WITH ICA COMPONENTS CALCULATED TO A NEW DATASET. 

    ica_nom = strcat(EEG.setname,'-ica');

    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG_out, CURRENTSET,'setname',char(ica_nom),'gui','off'); % current set = xx;
    EEG = eeg_checkset( EEG );
    EEG = pop_saveset( EEG, 'filename',char(ica_nom),'filepath',EEG.filepath); 
    eeglab redraw

    %% RUN THE ADJUST TOOLBOX TO AUTOMATICALLY DETECT IC COMPONENTS CORRESPONDING TO ARTIFACTS

    report_nom = strcat(EEG.setname,'_icareport');
    report_out = fullfile(EEG.filepath,report_nom);
    EEGout = EEG;            % Adjust algorithm seems to work better when it computes ICAs itself.
    EEGout.icaact = [];

    % Calculate component statistics.
    % This function creates a text file summarizing the results of the
    % statistical analyses and identifying components corresponding to
    % artifacts.

    [art, horiz, vert, blink, disc,soglia_DV, diff_var, soglia_K, med2_K, meanK,...
        soglia_SED, med2_SED, SED, soglia_SAD, med2_SAD, SAD,soglia_GDSF, med2_GDSF,...
        GDSF, soglia_V, med2_V, nuovaV, soglia_D, maxdin,max_var,activs] = ADJUST (EEGout,report_out);


    %% Present the topographies of the ICA components with component spectra and
    % statistics. 
    compnum = 1:size(EEG.icawinv,1);
    EEGout.icaact = activs; 

    [EEG,com] = pop_selectcomps_ADJ(EEGout, compnum, art, horiz, vert, blink, disc,...
            soglia_DV, diff_var, soglia_K, med2_K, meanK, soglia_SED, med2_SED, SED, soglia_SAD, med2_SAD, SAD, ...
            soglia_GDSF, med2_GDSF, GDSF, soglia_V, med2_V, max_var, soglia_D, maxdin);

    %% OPTION TO REJECT ICA COMPONENTS SELECTED
    % The selected ICA components are recorded in the field
    % EEG.reject.gcompreject.

    icarej_ans = 'yes';
    comps2rem = find(EEG.reject.gcompreject);   % Those components marked for rejection. 

    % Open dialogue box asking user if they would like to remove the marked
    % components.
    prompt2 = strcat('Would you like to remove components ',num2str(comps2rem),' ?');
    dlg_title2='Reject marked components';
    num_lignes2= 1;
    deflts2={'yes'};      % Or 'no'
    comp_ans=inputdlg(prompt2,dlg_title2,num_lignes2,deflts2);

    if strcmp(comp_ans{1,1},'yes')   

        EEG = pop_subcomp(EEG,comps2rem,1);  %call of function pop_subcomp() to remove ICA components. 
        EEG.reject.icarejmanual = comps2rem; 

        % Save the current data with the ICA components removed. 
        [ALLEEG, EEG]=eeg_store(ALLEEG, EEG, CURRENTSET);
        EEG=eeg_checkset(EEG);
        EEG=pop_saveset(EEG, 'filename',char(strcat(char(EEG.setname),'rej')),'filepath',EEG.filepath); %change EEG.filepath
        eeglab redraw

    else
        disp('----------Not removing ICA components for the moment-------------------');

    end

end 