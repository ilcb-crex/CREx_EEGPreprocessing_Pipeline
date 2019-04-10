function [peak_mag,peak_f] = CREx_SpectCalc_multitap(EEG,chansoi,freqs,foi,figinfo)
% Function to analyse spectrum using multitapers. 
% Needs to call the function : mtspectrumsegc().

%% Define the parameters
params.triallen=(floor(EEG.times(end)/10)/1000+abs(EEG.times(1)/1000));                       %length of the trial in seconds
params.bw = 3;                                                                                              % (Hz) defines the width of a spectral peak for a sinusoid at fixed frequency. As such, this defines the multi-taper frequency resolution.
params.winsize=  params.triallen/1;                                                                  % window size is equal to the trial length
params.winstep= params.winsize/1;                                                                  %default of no overlap ==> step the same size as the window length
params.halfbw= params.bw/2;                                                                      % half bandwidth                                                                   %define the line frequencies
params.fpass= freqs;
params.pval = 0.05;                                                                                    %define the p-value for the detection of sinusoidal components
params.chanlist = chansoi ;                                                                                %the number of channels to analyse
params.Fs = EEG.srate;                                                                                % the sampling frequency
params.tau = 5;   % 10Inf, smoothing parameter.                                                                                      %smoothing factor; Inf ==> no smoothing
params.pad= 0;                                                                                         %the padding factor to a power of 2 of the sliding window length. NFFT = 2^nextpow2(SlidingWinLen*(PadFactor+1)). e.g. For N = 500, if PadFactor = -1, we do not pad; if PadFactor = 0, we pad the FFT to 512 points, if PadFactor=1, we pad to 1024 points etc.'),
params.movingwin =[params.winsize params.winstep];
params.movingwinlen = params.movingwin(1)*params.Fs; 

pl=zeros(length(params.chanlist),1);      % Initialise the handles vector

if params.pad>=0
    NFFT = 2^nextpow2(params.movingwinlen*(params.pad+1));
else
    NFFT = params.movingwinlen;
end

params.nfft = NFFT;
params.timebwprod = params.halfbw*params.winsize;          %time bandwidth product  (WN)
params.ndiff = rem(EEG.pnts,(params.winsize*params.Fs));   %the difference left over when the total data length is divided by the window length.
params.tapernum = 2*params.halfbw*params.winsize-1;        %Number of tapers equalling 1 : 2WN-1
params.overlap = params.winsize-params.winstep;
params.toverlap = -params.overlap/2:(1/EEG.srate):params.overlap/2;               %overlap in time domain
params.smooth = 1-1./(1+exp(-params.tau.*params.toverlap/params.overlap));  %the smoothing is a function of the smoothing factor, tau, and the taper overlap

assignin('base','dpssparams',params);
%% Check that the moving averager length is less than or equal to EEG.pnts/EEG.srate

if params.winsize>EEG.pnts/EEG.srate
    display('A problem guys! The length of your analysis window is longer than your epoch length...think of the effects of the discontinuities!');
end

%% 
Spectall = cell(length(chansoi),size(EEG.data,3));


for chan_cnt = 1:length(params.chanlist) % As the data maybe epoched
    
    for tcnt = 1:size(EEG.data,3) % tcnt ==> trial count
        
        datasq = squeeze(EEG.data(params.chanlist,:,tcnt));
        data=datasq';
        
        [Spectall{chan_cnt,tcnt},f] = mtspectrumsegc(data(:,chan_cnt),params.movingwin(1),params);
        
        if tcnt ==1
            S = Spectall{chan_cnt,tcnt};
        else
            S = cat(2,S,Spectall{chan_cnt,tcnt});
        end 
    end
    if chan_cnt==1
        spectmean = zeros(64,size(S,1));
        spectmean(chan_cnt,:) = mean(S,2);
    else
        spectmean(chan_cnt,:) = mean(S,2);
    end
end 

assignin('base','S',S)
assignin('base','Spectall',Spectall)
assignin('base','spectmean',spectmean);
assignin('base','f',f);

chans = {EEG.chanlocs(chansoi).labels};
chan_ind = chansoi;
wbh=waitbar (0,'Please wait...');  %Initialise the waitbar
figure; set(gcf,'Color',[1 1 1]);

for counter = 1:length(chansoi)
    
    h(counter) = plot(f,10*log10(spectmean(counter,:)));   %
    set(h(counter),'HitTest','on','SelectionHighlight','on','UserData',chans{counter});
    set(h(counter),'ButtonDownFcn',@dispElectrode);   % displays the channel label upon mouse click

    hold all


    waitbar(counter/length(chan_ind));

end 

xlabel('Frequency (Hz)')
ylabel('Log Power Spectral Density (V^2/Hz)')
title(strcat('PSD: ',EEG.setname))
xlim([f(1) f(end)]);

delete(wbh);  %close the waitbar

%% Save the current figure to file if a file path and name is specified

saveas(gcf,figinfo,'fig');



%%
% 
% peak_mag = cell(1,64);
% peak_f = cell(1,64);
% 
% f1 = figure;
% for chancnt = 1:64
%     
% %     s = polyfit(f,spectmean(chancnt,:),1);
% %     spectmean_poly = polyval(s,f);
% %     spectmean_corr = spectmean(chancnt,:)-spectmean_poly;
% %      spectmean_corr = detrend(10*log10(spectmean(chancnt,:)));
%     
%     if ~isempty(foi)
%         findx = find(f>=foi(1) & f<=foi(2));
%     else
%         foi = [freqs(1) freqs(end)];
%         findx = find(f>=foi(1) & f<=foi(2));
%     end
%     
%     spectmean_foi = spectmean(chancnt,findx);
%     [~,locs] = findpeaks(10*log10(spectmean_foi),'MINPEAKHEIGHT',prctile(10*log10(spectmean_foi),90));
%     X = nan(1,size(findx,2));
%     %X(1,locs) = 10*log10(spectmean_foi(locs)); 
% %    y = 10*log10(spectmean_foi);
%      y = spectmean_foi;
%      X(locs) = spectmean_foi(locs);
%     
%      peak_mag{1,chancnt} = y(locs);
%      peak_f{1,chancnt} = f(locs);
%     
%     subplot(8,8,chancnt)
%     plot(f(findx),10*log10(y));
%     hold on
%     plot(f(findx),10*log10(X),'ro');
%    
%     title(EEG.chanlocs(chancnt).labels)
%     axhdl = gca;
%     
%     set(f1,'CurrentAxes',axhdl);
%     set(axhdl,'HitTest','on','SelectionHighlight','on','UserData',{f(findx),y,EEG.chanlocs(chancnt).labels,X},'NextPlot','add');
%     set(axhdl,'ButtonDownFcn',@plotsingle_spectre)
%     
% 
% end


end

function dispElectrode(hdl,~)

disp(get(hdl,'UserData'));
set(hdl,'LineWidth',2.5);


end




