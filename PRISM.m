%% PRISM: Post-processing ROI Inspection, Sorting, & Merging
% Matlab GUI to clean (calcium) imaging datasets 
% cells, axons, dendrites, 1-, and 2- photon imaging datasets

% It loads CNMF-E (.mat), CNMF (Caiman) (.mat or .hdf5), and Suite2P (.mat) files
% GUI allows the user to manually curate data
% After deleting, merging, or both, it saves data as a .mat file for future analyses

% caiman/cnmf-e/suite2p reject ROIs (rois_bad), you can decide to plot those
% (check plot bad rois). if you do, those ROIs will go to the delete list

% due to it's underlying structure, you need to delete or merge (not both
% at the same time)

% you can perform a delete after a merge and the other way around, except
% that merge pairs will not be redetected -> reload data to do so

% in practice, you might have multiple rounds of deleting and merging
% (run GUI, save data, restart GUI, reload those data, and continue)

% based on miniscope GUI (Aishwarya Parthasarathy and Bastijn van den Boom
% at Willuhn lab, NIN, Amsterdam)
% 2026 Bastijn van den Boom (Sabatini lab, HMS, Boston)


function varargout = PRISM(varargin)
% PRISM MATLAB code for PRISM.fig
%      PRISM, by itself, creates a new PRISM or raises the existing
%      singleton*.
%
%      H = PRISM returns the handle to a new PRISM or the handle to
%      the existing singleton*.
%
%      PRISM('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PRISM.M with the give0n input arguments.
%
%      PRISM('Property','Value',...) creates a new PRISM or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before PRISM_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to PRISM_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help PRISM

% Last Modified by GUIDE v2.5 02-Jul-2026 20:04:07

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @PRISM_OpeningFcn, ...
    'gui_OutputFcn',  @PRISM_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before PRISM is made visible.
function PRISM_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to PRISM (see VARARGIN)

% Read and display logo
img = imread('PRISM_logo.png'); % Specify your image path here
imshow(img, 'Parent', handles.logo); % Direct it to the GUIDE axes

% Choose default command line output for PRISM
handles.output = hObject;

% allow updating of plotting bad ROIs
handles.plot_bad_update = 1;

% NOTE: 'zoom on' used to run here, but any active interactive mode
% (zoom, pan, or the toolbar's Data Cursor button) intercepts mouse
% clicks before ax2's ButtonDownFcn ever runs, which breaks click-to-
% select-ROI. Keep the toolbar off and leave interactive modes disabled
% (see start_gui_Callback) so clicking a contour always selects it.

% open in center of screen
movegui(hObject, 'center');

% start_gui handles structure
guidata(hObject, handles);

% disable buttons
set(handles.start_gui, 'Enable', 'off');
set(handles.del, 'Enable', 'off');
set(handles.merge, 'Enable', 'off');
set(handles.save, 'Enable', 'off');

% UIWAIT makes PRISM wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = PRISM_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BASIC GUI


% --- Executes on button press in LoadFile.
function LoadFile_Callback(hObject, eventdata, handles)
% hObject    handle to LoadFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% clear command window
clc

% disable buttons that depend on a completed start_gui pass on the
% about-to-be-loaded data - prevents stale-data errors if the user
% clicks these before hitting "Start GUI" again (see start_gui_Callback)
set(handles.start_gui, 'Enable', 'off');
set(handles.del, 'Enable', 'off');
set(handles.merge, 'Enable', 'off');
set(handles.save, 'Enable', 'off');

% wipe every plot axes so nothing from the previous session is left on
% screen while the new file loads (previously these just sat there,
% unchanged, until "Start GUI" repopulated them)
cla(handles.ax1);
cla(handles.ax2);
cla(handles.distcorr);
cla(handles.histsnr);
cla(handles.histsize);

% clear the user update text box too
set(handles.user_alert, 'String', '');

% explicitly invalidate the persistent ROI background/contour cache too
% (see ensure_roi_background). cla() above deletes the cached graphics
% objects, which ensure_roi_background's isgraphics() checks would catch
% on their own - this just makes the reset explicit rather than relying
% on that fallback
setappdata(handles.ax2, 'roi_bg_cache', []);

% clear handles fields of cnmf
handles.rawdata1 = [];
handles.updatedCraw = [];
handles.updatedC = [];
handles.updatedA = [];
handles.updatedS = [];
handles.updatedresiduals = [];
handles.updatedSNRcnmf = [];
handles.SNR = [];
handles.cn_display_transposed = false; % see the Cn-orientation fix below and in build_native_cnmfe
handles.mergecells = [];
handles.delcells = [];
handles.pixels_A = [];
handles.dist_mat = [];
handles.corr_mat = [];
handles.dist = [];
handles.corr = [];
handles.pairs_currentcompare = [];
handles.multimergeidx = [];
handles.plot_roi = [];
handles.manualpair = [];
% these are text/edit display controls, so it's 'String' (not 'Value')
% that actually clears what's shown - 'Value' was a no-op on them,
% which is why the single-ROI and merge-pair stats used to keep showing
% the previous session's numbers after Load
set(handles.cell_pair1, 'String', '');
set(handles.cell_pair2, 'String', '');
set(handles.cell_pair_dist, 'String', '');
set(handles.cell_pair_corr, 'String', '');
set(handles.n_pair, 'String', []);
set(handles.plot_rois, 'Value', 0); % this one is a checkbox - 'Value' is correct
set(handles.roi_idx, 'String', '');
set(handles.n_rois, 'String', '');
set(handles.roi_snr, 'String', '');
set(handles.roi_size, 'String', '');

% clear panels
set(handles.deletelist, 'String', sprintf('ROIs to delete'), 'Value', 1); % update values in deletelist
set(handles.mergelist, 'String', sprintf('ROIs to merge'), 'Value', 1); % update values in mergelist
set(handles.checkmergetxt, 'String', 'Click "Find repeats"'); % update values in mergelist

% user select file. Test/batch hook: if a full path is stashed in the
% root appdata 'PRISM_test_infile', use it and skip the dialog (lets the
% self-test drive load->save without user interaction).
test_infile = getappdata(0, 'PRISM_test_infile');
if ~isempty(test_infile)
    [fp, fn, fe] = fileparts(test_infile);
    filepath1 = [fp filesep];
    filename1 = [fn fe];
else
    [filename1, filepath1] = uigetfile('*.*', 'Select raw .hdf5 cnmf (caiman), Fall.mat (Suite2P), ~.mat (CNMF-E), or .mat preprocessed file');
end

% user cancelled the dialog (or closed it) without picking a file -
% uigetfile then returns 0 for both outputs, and cd(0)/strsplit(0,...)
% below would error. Bail out cleanly instead of crashing.
if isequal(filename1, 0) || isequal(filepath1, 0)
    set(handles.user_alert, 'String', 'Please select a file');
    guidata(hObject, handles);
    return
end

cd(filepath1)

% remember the source file so save can write native output in the same
% format (and, for cnmf .hdf5, copy-and-patch the original - see save)
handles.source_file = [filepath1 filename1];

% update user
set(handles.user_alert, 'String', sprintf('Loading data, please wait...'));
pause(0.1); % make sure to update user_alert

% check if we want to plot bad ROIs
handles.plot_bad = get(handles.check_plot_bad, 'Value'); % 0=good ROIs, 1=bad ROIs
handles.plot_bad_update = 0;    % prevent updating bad ROI plotting

% check if file is a (preprocessed) .mat file or directly .hdf5 output of cnmf (caiman)
tmp = strsplit(filename1, '.');
tmp = tmp{end};

% update user and load data
if strcmp(tmp, 'mat') % mat file
    % detect suite2p Fall.mat by presence of 'iscell' variable
    file_vars = {whos('-file', [filepath1 filename1]).name};
    if any(strcmp(file_vars, 'iscell')) % suite2p output
        % update user
        set(handles.user_alert, 'String', sprintf('Loading suite2p .mat, please wait...'));
        pause(0.1); % make sure to update user_alert
        % load file
        handles.rawdata1.results = load_suite2p_mat(filename1, filepath1, handles);
    else % cnmf/caiman preprocessed .mat
        % update user
        set(handles.user_alert, 'String', sprintf('Loading .mat file, please wait...'));
        pause(0.1); % make sure to update user_alert
        % load file
        handles.rawdata1 = load([filepath1 filename1]);   % all raw data
        % backward compatibility: rename options -> settings for older saved files
        if isfield(handles.rawdata1.results, 'options') && ~isfield(handles.rawdata1.results, 'settings')
            handles.rawdata1.results.settings = handles.rawdata1.results.options;
        end
        % old MATLAB CNMF-E has transposed Cn (no Mn field) — fix orientation
        % only applies to raw legacy CNMF-E .mat (no pipeline tag yet); skip once
        % settings.pipeline exists (suite2p/cnmf) OR the file was already
        % cleaned by PRISM (carries a PRISM field) - otherwise reloading a
        % cleaned CNMF-E file for another round would re-transpose Cn.
        if ~isfield(handles.rawdata1.results.settings, 'pipeline') && ...
                ~isfield(handles.rawdata1.results.settings, 'fnames') && ...
                ~isfield(handles.rawdata1.results, 'PRISM')
            handles.rawdata1.results.Cn = handles.rawdata1.results.Cn';
            % this transpose is for GUI display only - build_native_cnmfe
            % undoes it before saving so the output file's Cn matches the
            % ORIGINAL file's orientation, not this display-oriented copy
            handles.cn_display_transposed = true;
        end
        % update bad ROIs if needed
        if handles.plot_bad == 1 % update results
            handles.rawdata1.results.C_raw = handles.rawdata1.results.raw.C_raw;
            handles.rawdata1.results.C = handles.rawdata1.results.raw.C;
            handles.rawdata1.results.S = handles.rawdata1.results.raw.S;
            handles.rawdata1.results.A = handles.rawdata1.results.raw.A;
            handles.rawdata1.results.rois_bad = handles.rawdata1.results.raw.rois_bad;
            try % not everyone has these vars
                handles.rawdata1.results.residuals = handles.rawdata1.results.raw.residuals;
                handles.rawdata1.results.SNR_cnmf = handles.rawdata1.results.raw.SNR_cnmf;
            catch end
        end
    end

elseif strcmp(tmp, 'hdf5') % raw output
    % update user
    set(handles.user_alert, 'String', sprintf('Loading Caiman .hdf5 file, please wait...'));
    pause(0.1); % make sure to update user_alert
    % load file
    handles.rawdata1.results = load_cnmf_hdf5(filename1, filepath1, handles);

else
    % update user
    set(handles.user_alert, 'String', sprintf('Unknown file format, please select .mat or .hdf5'));
    pause(0.1); % make sure to update user_alert
    error('Unknown file format')
end

% extract variables
handles.updatedCraw = handles.rawdata1.results.C_raw;
handles.updatedC = handles.rawdata1.results.C;
handles.updatedA = handles.rawdata1.results.A;
handles.updatedS = handles.rawdata1.results.S;
try % not everyone has these vars 
    handles.updatedresiduals = handles.rawdata1.results.residuals;
    handles.updatedSNRcnmf = handles.rawdata1.results.SNR_cnmf;
catch end
% identify the source pipeline so save can write native output (see
% save_Callback). The loaders tag settings.pipeline as 'suite2p'/'cnmf';
% a raw MATLAB CNMF-E .mat has no such tag -> 'cnmfe'.
if isfield(handles.rawdata1.results, 'settings') && isfield(handles.rawdata1.results.settings, 'pipeline')
    handles.source_pipeline = handles.rawdata1.results.settings.pipeline; % 'suite2p' or 'cnmf'
else
    handles.source_pipeline = 'cnmfe';
end

% native_index maps each working ROI to its index in the source file's
% full component axis. suite2p/cnmf loaders return it (accounts for the
% good-only subset when plot bad rois is off); a plain .mat is 1:N.
if isfield(handles.rawdata1.results, 'native_index')
    handles.native_index = double(handles.rawdata1.results.native_index(:))';
else
    handles.native_index = 1:size(handles.updatedCraw,1);
end

% detect a file PRISM has already cleaned. New files carry a PRISM struct;
% older ones used results.GUI = 'true'. Either way the original ROI
% numbers no longer match the pipeline's rois_bad, so bad-ROI plotting is
% blocked on such files.
handles.prism_used = isfield(handles.rawdata1.results, 'PRISM');
if ~handles.prism_used
    try, handles.prism_used = strcmp(handles.rawdata1.results.GUI, 'true'); catch, end
end

% check if we need to update bad ROIs
if handles.plot_bad == 1 % update results
    if handles.prism_used % have we cleaned these data before?
        % update user
        set(handles.user_alert, 'String', sprintf('GUI has been used before on bad rois!'));
        pause(0.1); % make sure to update user_alert
        error('PRISM has been used before on these data, you cannot use bad ROIs because the ROI numbers probably will not match')
    end
    handles.rois_bad = handles.rawdata1.results.raw.rois_bad;
end

% update total n ROIs
set(handles.n_rois, 'String', sprintf('%d', size(handles.updatedCraw,1))); % update total n ROIs

% update user
set(handles.user_alert, 'String', sprintf('Data loaded, start GUI'));
pause(0.1); % make sure to update user_alert

% enable button
set(handles.start_gui, 'Enable', 'on');

% store data
guidata(hObject,handles);


% --- Executes on button press in start_gui.
function start_gui_Callback(hObject, eventdata, handles)
% hObject    handle to start_gui (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% disable button
set(handles.start_gui, 'Enable', 'off');

% update user
set(handles.user_alert, 'String', sprintf('Starting GUI, please wait...'));
pause(0.1); % make sure to update user_alert

% clear panels
set(handles.deletelist, 'String', sprintf('ROIs to delete'), 'Value', 1); % update values in deletelist
set(handles.mergelist, 'String', sprintf('ROIs to merge'), 'Value', 1); % update values in mergelist
set(handles.checkmergetxt, 'String', 'Click "Find repeats"'); % update values in mergelist

% move all the bad ROIs to the delete list if we're plotting bad ROIs
if handles.plot_bad == 1
    handles.rois_bad = double(handles.rois_bad); % make it double
    handles.delcells = handles.rois_bad; % update delcells list
    set(handles.deletelist, 'String', handles.rois_bad, 'Value', length(handles.rois_bad)); % add values to delete list
end

% define colors
handles.colors = [56/255 176/255 0/255; 0/255 0/255 255/255; 255/255 0/255 0/255; 167/255 201/255 87/255]; % green, blue, red [single ROI, 2x dual ROIs, all contours]
handles.color_plots = [.5 0 .5; 251/255 111/255 146/255]; % purple, pink [distance x corr and histo plots, selected ROIs]

% initialise original-index tracking: each working ROI starts as exactly
% one source ROI (its native_index). del_Callback and merge_Callback keep
% this in sync (merged ROIs hold several native indices) so save can
% rebuild a native file (see build_native_* / patch_hdf5).
if isfield(handles, 'native_index')
    handles.roi_orig = num2cell(handles.native_index);
else
    handles.roi_orig = num2cell(1:size(handles.updatedCraw,1));
end

% calculate SNR
handles.SNR = get_SNR(handles.updatedC, handles.updatedCraw);

% % find peaks and baseline
% for i = 1:size(handles.rawdata1.results.C_raw,1)    % per roi
%     [pk{i}, loc{i}] = findpeaks(handles.updatedC(i,:)); % , 3
%
% end
% % find baseline
%
% % calculate SNR - divide by baseline
% handles.SNR=[];deletelist
% for i=1:size(handles.rawdata1.results.C_raw,1)    % per roi [size(handles.updatedCraw,1)]
%     [b, sn] = estimate_baseline_noise(handles.updatedCraw(i,:))
%     handles.SNR(i) = median(pk{i})/sn;
%     clear sn;
% end

% % find ROIs with low SNR and remove those ROIshandles.SNR
% idx_snr = find(handles.SNR < str2num(get(handles.snr_thres,'String')));
% handles.updatedCraw(idx_snr,:) = [];
% handles.updatedC(idx_snr,:) = [];
% handles.updatedS(idx_snr,:) = [];
% handles.updatedA(:,idx_snr) = [];
% handles.SNR(idx_snr) = [];

% find ROIs with low SNR and add to deletelist
idx_snr = find(handles.SNR < str2num(get(handles.snr_thres,'String')));
if ~isempty(idx_snr)
    tmp_list = handles.delcells; % get list
    tmp_list = [tmp_list idx_snr]; % add roi
    handles.delcells = tmp_list; % update del list
    set(handles.deletelist, 'String', handles.delcells, 'Value', length(handles.delcells)); % update values in list
end

% get full ROI, center of mass, and size A
[handles.Cent_N, handles.pixels_A, handles.Afull] = get_shape_size_A(handles);

% % loop through roi pairs to get correlation and distance - SLOW step
% for i = 1:size(handles.updatedCraw,1) % for each roi
%     for j = i:size(handles.updatedCraw,1) % for each other roi
%         handles.dist_mat(j,i) = sqrt((Cent_N(i,1) - Cent_N(j,1))^2 + (Cent_N(i,2) - Cent_N(j,2))^2); % get distance
%         handles.corr_mat(j,i) = corr(handles.updatedCraw(i,:)',handles.updatedCraw(j,:)'); % get correlation
%     end
% end

% % for dist and corr: get lower triangular part of matrix by replacing the top part with NaNs
% tril_mask = tril(true(size(handles.dist_mat)), -1);
% handles.dist_mat(~tril_mask) = NaN;
% handles.corr_mat(~tril_mask) = NaN;

% vectorized distance and correlation across all ROI pairs
dist_mat_full = squareform(pdist(handles.Cent_N, 'euclidean'));   % [N x N] pairwise distances
corr_mat_full = corr(handles.updatedCraw');                % [N x N] pairwise correlations (updatedCraw is [N x T], corr expects [T x N])

% keep only lower triangular part (below diagonal), set rest to NaN
tril_mask = tril(true(size(dist_mat_full)), -1);
handles.dist_mat = dist_mat_full;
handles.corr_mat = corr_mat_full;
handles.dist_mat(~tril_mask) = NaN;
handles.corr_mat(~tril_mask) = NaN;

% find ROIs that are too small (a_min) or big (a_max)
idx_amin = [];
idx_amax = [];
if str2num(get(handles.a_min,'String')) ~= 0
    idx_amin = find(handles.pixels_A < str2num(get(handles.a_min,'String')));
end
if str2num(get(handles.a_max,'String')) ~= 0
    idx_amax = find(handles.pixels_A > str2num(get(handles.a_max,'String')));
end
idx_a = unique([idx_amin idx_amax]);

% % remove those ROIs
% handles.updatedCraw(idx_a,:) = [];
% handles.updatedC(idx_a,:) = [];
% handles.updatedS(idx_a,:) = [];
% handles.updatedA(:,idx_a) = [];
% handles.SNR(idx_a) = [];

% add those ROIs to the dellist
if ~isempty(idx_a)
    tmp_list = handles.delcells; % get list
    tmp_list = [tmp_list idx_a]; % add roi
    handles.delcells = tmp_list; % update del list
    set(handles.deletelist, 'String', handles.delcells, 'Value', length(handles.delcells)); % update values in list
end

% find pairs of ROIs that fullful dist_thres & corr_thres
[handles.pairs_cells1, handles.pairs_cells2] = find(handles.dist_mat < str2num(get(handles.dist_thres,'String')) & ...
    handles.corr_mat > str2num(get(handles.corr_thres,'String')));

% set dropdown to merge pairs
% set(handles.roi1, 'String', unique([handles.pairs_cells1 handles.pairs_cells2]));
% set(handles.roi2, 'String', unique([handles.pairs_cells1 handles.pairs_cells2]));

% set dropdown to all possible rois
set(handles.roi1, 'String', [1:size(handles.updatedCraw,1)]);
set(handles.roi2, 'String', [1:size(handles.updatedCraw,1)]);

% make matrix into vector
handles.dist = reshape(handles.dist_mat, 1, size(handles.dist_mat,1)*size(handles.dist_mat,2));
handles.corr = reshape(handles.corr_mat, 1, size(handles.corr_mat,1)*size(handles.corr_mat,2));
idx = isnan(handles.dist); % find NaN's (which is top part and the diagonal)
handles.dist(idx)=[];
handles.corr(idx)=[];

% if we include bad ROIs, we'll start by plotting single ROIs. otherwise ROI pairs
if handles.plot_bad == 1 % bad ROIs
    % store that we plot a single ROI
    handles.to_plot = 1;

    % ROI to plot
    tmp = str2num(get(handles.deletelist,'String'));
    try
        % plot first bad ROI
        idx = tmp(1);
    catch
        % plot first ROI
        idx = 1;
        
        % update user
        set(handles.user_alert, 'String', sprintf('No bad ROIs found!'));
        pause(0.1); % make sure to update user_alert
    end

    handles.plot_roi = idx;

    % select the first ROI in the dellist
    set(handles.deletelist, 'String', get(handles.deletelist,'String'), 'Value', 1);

    % start a compare pair
    handles.pairs_currentcompare = 1;
else
    % store that we plot a mergepair
    handles.to_plot = 0;

    % ROI(s) to plot
    handles.pairs_currentcompare = 1;

    % based on the settings, we might find no pairs at all
    try
        idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
    catch
        % store that we plot a single ROI since there are no merge pairs
        handles.to_plot = 1;
        % plot the first ROI
        idx = 1;
    end
end

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% plot distance vs crosscorr: all data
plot(handles.distcorr, handles.dist, handles.corr, '.', 'Color', handles.color_plots(1,:), 'LineStyle', 'none', 'MarkerSize', 10);
ylim(handles.distcorr, [-1 1]); % set y-axis limits
hold(handles.distcorr,'on')

% define slider location
set(handles.slidertoaddtodellist, 'Min', 1, 'Max', size(handles.updatedCraw,1), 'SliderStep', [1/(size(handles.updatedCraw,1)-1),1], 'Value', 1)

% plot number of roi pairs that fulfill criteria
set(handles.n_pair, 'String', sprintf('%d pairs of ROIs satisfy the thresholds', length(handles.pairs_cells1)));

% plot histogram of SNR
plot_histo_snr(handles)

% plot histogram of size
plot_histo_size(handles)

% update user
if handles.to_plot == 0  % plotting merge pairs
    set(handles.user_alert, 'String', sprintf('Plotting ROIs: %s', num2str(idx)));
else
    set(handles.user_alert, 'String', sprintf(['Plotting ROI: ' num2str(idx)]));
end
pause(0.1);

% enable button
set(handles.save, 'Enable', 'on');

% force off the figure's classic interactive modes (zoom/pan/data cursor)
% in case a toolbar button toggled one on - these would otherwise
% intercept clicks before ax2's ButtonDownFcn (see plot_spatial_components)
% ever runs
zoom(handles.figure1, 'off');
pan(handles.figure1, 'off');
datacursormode(handles.figure1, 'off');

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


% --- Executes on button press in restart_gui.
function restart_gui_Callback(hObject, eventdata, handles)
% hObject    handle to restart_gui (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get the current figure handle
fig = handles.figure1;  % Adjust if your figure has a different name

% Get the GUI's filename (without the .fig extension)
guiName = 'PRISM';

% Close the current GUI
close(fig);

% Restart the GUI
feval(guiName);


% --- Executes on button press in del.
function del_Callback(hObject, eventdata, handles)
% hObject    handle to del (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% disable button
% set(handles.del,   'Enable', 'off');

% update user
set(handles.user_alert, 'String', sprintf('Deleting ROIs, please wait...'));
pause(0.1); % make sure to update user_alert

% get deletelist and delete values
del_rois = str2num(get(handles.deletelist,'String'));
handles.updatedCraw(del_rois,:) = [];
handles.updatedC(del_rois,:) = [];
handles.updatedS(del_rois,:) = [];
handles.updatedA(:,del_rois) = [];
try % not everyone has these vars
    handles.updatedresiduals(del_rois,:) = [];
catch end
% NOTE: SNR_cnmf (when present) is intentionally NOT re-indexed here -
% see the comment in build_native_cnmfe for why.
handles.SNR(:,del_rois) = [];
handles.pixels_A(:,del_rois) = [];
handles.roi_orig(del_rois) = []; % keep original-index map in sync

% clear del_list
set(handles.deletelist,'String',[]);
handles.delcells = []; % also clear internal queue, else stale/shrunk indices carry over

% reset single-ROI browsing state so it doesn't point at stale/shrunk
% indices if the user immediately continues deleting or merging
handles.plot_roi = 1;
n_rois_now = size(handles.updatedCraw,1);
set(handles.slidertoaddtodellist, 'Min', 1, 'Max', n_rois_now, ...
    'SliderStep', [1/max(n_rois_now-1,1), 1], 'Value', 1);
set(handles.roi1, 'String', 1:n_rois_now, 'Value', 1);
set(handles.roi2, 'String', 1:n_rois_now, 'Value', 1);

% update number of ROIs
set(handles.user_alert, 'String', sprintf('Plotting all ROIs, please wait...'));
pause(0.1); % make sure to update user_alert

% update total n ROIs
set(handles.n_rois, 'String', sprintf('%d', size(handles.updatedCraw,1))); % update total n ROIs

% delete rois_bad values if we plotted those
if handles.plot_bad == 1 % plot bad ROIs
    handles.rois_bad = [];
end

% get full ROI, center of mass, and size A
[handles.Cent_N, handles.pixels_A, handles.Afull] = get_shape_size_A(handles);

% plot histogram of SNR
plot_histo_snr(handles)

% plot histogram of size
plot_histo_size(handles)

% plot all rois
% ROI(s) to plot
idx = 1:size(handles.updatedCraw,1); % all ROIs

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% update user
set(handles.user_alert, 'String', sprintf('Done deleting, save data!\n Number of ROIs: %d', size(handles.updatedCraw,1)))

% store data
guidata(hObject,handles);


% --- Executes on button press in merge.
function merge_Callback(hObject, eventdata, handles)
% hObject    handle to merge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% disable button
% set(handles.merge, 'Enable', 'off');

% update user
set(handles.user_alert, 'String', sprintf('Merging ROIs, please wait...'));
pause(0.1); % make sure to update user_alert

% get ROIs to merge
merge_rois = get(handles.mergelist,'String');

% average activity (Craw, C, S) and combine contours (A)
rois_keep = []; % first ROIs of the pairs, to  keep
rois_delete = []; % all the other ROIs, to delete
merged_orig = {}; % original-index union per merged ROI (for roi_orig)
for i = 1:length(merge_rois) % per mergepair

    % temporal activity
    rois_pair = sort(str2num(cell2mat(merge_rois(i))),'ascend');
    rois_craw = [];
    rois_c = [];
    rois_s = [];
    rois_res = [];
    for u = 1:length(rois_pair) % per roi in mergepair
        rois_craw = [rois_craw; handles.updatedCraw(rois_pair(u),:)];
        rois_c = [rois_c; handles.updatedC(rois_pair(u),:)];
        rois_s = [rois_s; handles.updatedS(rois_pair(u),:)];
        try % not everyone has these vars
            rois_res = [rois_res; handles.updatedresiduals(rois_pair(u),:)];
        catch end
    end
    merged_craw(i,:) = mean(rois_craw);
    merged_c(i,:) = mean(rois_c);
    merged_s(i,:) = mean(rois_s);
    merged_res(i,:) = mean(rois_res);
    % NOTE: SNR_cnmf (when present) is intentionally NOT accumulated/
    % re-indexed here - see the comment in build_native_cnmfe for why.

    % spatial contour
    rois_a = [];
    % merged_contour(:,i) = handles.updatedA(:,rois_pair(1));
    for u = 1:length(rois_pair) % per roi in mergepair
        rois_a = [rois_a handles.updatedA(:,rois_pair(u))];
    end
    merged_a(:,i) = sum(rois_a, 2);

    % keep track of ROIs
    rois_keep = [rois_keep rois_pair(1)]; % list of all first ROIs
    rois_delete = [rois_delete rois_pair(2:end)]; % list of all second and more ROIs

    % union of source ROIs behind this merged ROI (mirrors rois_keep)
    oo = [];
    for u = 1:length(rois_pair)
        oo = [oo handles.roi_orig{rois_pair(u)}];
    end
    merged_orig{i} = unique(oo);
end
handles.updatedCraw(rois_keep,:) = merged_craw; % store data on position first ROIs
handles.updatedCraw(rois_delete,:) = []; % remove other ROIs
handles.updatedC(rois_keep,:) = merged_c; % store data on position first ROIs
handles.updatedC(rois_delete,:) = []; % remove other ROIs
handles.updatedS(rois_keep,:) = merged_s; % store data on position first ROIs
handles.updatedS(rois_delete,:) = []; % remove other ROIs
handles.updatedA(:,rois_keep) = merged_a; % same for A
handles.updatedA(:,rois_delete) = [];
try % not everyone has these vars
    handles.updatedresiduals(rois_keep,:) = merged_res; % same for residuals
    handles.updatedresiduals(rois_delete,:) = [];
catch end

% keep original-index map in sync: merged ROI holds the union of its
% sources' original indices, then drop the merged-away partners
handles.roi_orig(rois_keep)   = merged_orig;
handles.roi_orig(rois_delete) = [];

% clear merge data
set(handles.mergelist,'String',[]);
handles.pwdist = [];
handles.crosscoef = [];
handles.pairs_cells1 = [];
handles.pairs_cells2 = [];
handles.mergecells = [];

% recompute SNR to match the merged (shrunk/re-averaged) ROI set - unlike
% delete, merge does not keep handles.SNR aligned as it goes, so it must
% be refreshed here rather than left stale until Save
handles.SNR = get_SNR(handles.updatedC, handles.updatedCraw);

% reset single-ROI browsing state so it doesn't point at stale/shrunk
% indices if the user immediately continues merging or deleting
handles.plot_roi = 1;
n_rois_now = size(handles.updatedCraw,1);
set(handles.slidertoaddtodellist, 'Min', 1, 'Max', n_rois_now, ...
    'SliderStep', [1/max(n_rois_now-1,1), 1], 'Value', 1);
set(handles.roi1, 'String', 1:n_rois_now, 'Value', 1);
set(handles.roi2, 'String', 1:n_rois_now, 'Value', 1);

% update user
set(handles.user_alert, 'String', sprintf('Plotting all ROIs, please wait...'));
pause(0.1); % make sure to update user_alert

% update total n ROIs
set(handles.n_rois, 'String', sprintf('%d', size(handles.updatedCraw,1))); % update total n ROIs

% delete rois_bad values if we plotted those
if handles.plot_bad == 1 % plot bad ROIs
    handles.rois_bad = [];
end

% get full ROI, center of mass, and size A
[handles.Cent_N, handles.pixels_A, handles.Afull] = get_shape_size_A(handles);

% plot histogram of SNR
plot_histo_snr(handles)

% plot histogram of size
plot_histo_size(handles)

% plot all rois
% ROI(s) to plot
idx = 1:size(handles.updatedCraw,1); % all ROIs

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% update user
set(handles.user_alert, 'String', sprintf('Done merging, save data!\n Number of ROIs: %d', size(handles.updatedCraw,1)))

% store data
guidata(hObject,handles);


function user_alert_Callback(hObject, eventdata, handles)
% hObject    handle to user_alert (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of user_alert as text
%        str2double(get(hObject,'String')) returns contents of user_alert as a double


% --- Executes on button press in save.
function save_Callback(hObject, eventdata, handles)
% hObject    handle to save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% disable button
set(handles.save, 'Enable', 'off');

% update user
set(handles.user_alert, 'String', sprintf('Preparing saving data, please wait...'));
pause(0.1); % make sure to update user_alert

% handles.SNR is already current here - computed once when the GUI
% starts (start_gui_Callback) and refreshed after every edit by
% del_Callback and merge_Callback

% find folder to save. Test/batch hook: skip the dialog if a target dir
% is stashed in root appdata 'PRISM_test_outdir'.
test_outdir = getappdata(0, 'PRISM_test_outdir');
if ~isempty(test_outdir)
    folder_name = test_outdir;
else
    folder_name = uigetdir;
end
if isequal(folder_name, 0) % user cancelled the folder dialog
    set(handles.user_alert, 'String', 'Save cancelled');
    set(handles.save, 'Enable', 'on');
    guidata(hObject, handles);
    return
end

% update user
set(handles.user_alert, 'String', sprintf('Storing data, please wait...'));
pause(0.1); % make sure to update user_alert

% assemble the PRISM provenance record (identical across formats).
% handles.SNR is already current - recomputed on start and after every
% delete/merge. A merged ROI is one whose roi_orig holds >1 source index.
n_out    = numel(handles.roi_orig);
is_merge = cellfun(@(x) numel(x) > 1, handles.roi_orig);
PRISM = struct();
PRISM.used            = true;                       % reload detects this
PRISM.version         = 'PRISM 2.0 (native output)';
PRISM.date            = datestr(now, 'yyyy-mm-dd HH:MM:SS');
PRISM.source_pipeline = handles.source_pipeline;    % suite2p | cnmfe | cnmf
PRISM.snr             = handles.SNR(:)';            % recomputed per surviving ROI
PRISM.n_out           = n_out;
PRISM.n_merged        = sum(is_merge);
PRISM.n_removed       = numel(handles.native_index) - n_out; % vs ROIs loaded
PRISM.merged_idx      = find(is_merge);            % output rows that are merges
PRISM.merged_sources  = handles.roi_orig(is_merge);% their source native indices
PRISM.roi_orig        = handles.roi_orig;          % output ROI -> source index map

% write native output in the SAME format as the input
% output keeps the input's base name with a _PRISM suffix, so the file
% NAME leads the differentiation while the CONTENT stays native.
[~, base] = fileparts(handles.source_file);
base = regexprep(base, '_PRISM$', '');   % avoid _PRISM_PRISM on re-saves
switch handles.source_pipeline
    case 'suite2p'
        file_str = fullfile(folder_name, [base '_PRISM.mat']);
        build_native_suite2p(handles, PRISM, file_str);
    case 'cnmfe'
        file_str = fullfile(folder_name, [base '_PRISM.mat']);
        build_native_cnmfe(handles, PRISM, file_str);
    case 'cnmf'
        file_str = fullfile(folder_name, [base '_PRISM.hdf5']);
        patch_hdf5(handles, PRISM, file_str);
    otherwise
        error('PRISM:unknownPipeline', 'Unknown source pipeline: %s', handles.source_pipeline);
end

% allow loading bad ROIs again
handles.plot_bad_update = 1;    % allow updating bad ROI plotting

% save screenshot figure (best-effort; skipped on a headless session)
try
    fig1_str = fullfile(folder_name, 'screenshot_GUI.png');
    frame = getframe(handles.figure1); % Capture the GUI figure
    imwrite(frame.cdata, fig1_str);    % Save as an image file
catch
end

% feedback to user
set(handles.user_alert, 'String', sprintf('Done saving! Saved at: %s', file_str));
pause(0.1); % make sure to update user_alert

% store data
guidata(hObject,handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DELETE ROIs


% --- Executes on slider movement.
function slidertoaddtodellist_Callback(hObject, eventdata, handles)
% hObject    handle to slidertoaddtodellist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% store that we plot 1 roi
handles.to_plot = 1;

% define range of slider
set(handles.slidertoaddtodellist, 'Max', size(handles.updatedCraw,1), 'Value', round(get(handles.slidertoaddtodellist,'Value')), 'SliderStep', [1/(size(handles.updatedCraw,1)-1),1]);

% ROI(s) to plot
handles.plot_roi = get(handles.slidertoaddtodellist,'Value');
idx = handles.plot_roi;

% update user
set(handles.user_alert, 'String', sprintf(['Plotting ROI: ' num2str(idx)]));
pause(0.1); % make sure to update user_alert

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% store data
guidata(hObject,handles);


% --- Executes on button press in add2dellist.
function add2dellist_Callback(hObject, eventdata, handles)
% hObject    handle to add2dellist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% store that we plot 1 roi
handles.to_plot = 1;

% add to del list
tmp_list = handles.delcells; % get list
tmp_list = [tmp_list handles.plot_roi]; % add roi
handles.delcells = tmp_list; % update del list
set(handles.deletelist, 'String', tmp_list, 'Value', length(tmp_list)); % update values in list

% add to go to next ROI (unless it's the last ROI)
if handles.plot_roi ~= size(handles.updatedCraw,1)

    % ROI(s) to plot
    handles.plot_roi= handles.plot_roi + 1;
    idx = handles.plot_roi;
    set(handles.slidertoaddtodellist, 'Max', size(handles.updatedCraw,1), 'Value', handles.plot_roi, 'SliderStep', [1/(size(handles.updatedCraw,1)-1),1]);

    % plot background (Cn or Mn) and ROI contours (idx)
    plot_spatial_components(handles, idx)

    % plot temporal traces of the first pair
    plot_temporal_traces(handles, idx)

    % plot ROI pair info
    plot_roi_info(handles, idx)

    % update user
    set(handles.user_alert, 'String', sprintf(['Plotting ROI: ' num2str(idx)]));
    pause(0.1); % make sure to update user_alert

end

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


% --- Executes on button press in rem4dellist.
function rem4dellist_Callback(hObject, eventdata, handles)
% hObject    handle to rem4dellist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% store that we plot 1 roi
handles.to_plot = 1;

% remove roi from dellist
k1 = get(handles.deletelist,'Value'); % get location
k2 = get(handles.deletelist,'String'); % get total list
k2(k1,:) = []; % remove from list
handles.delcells(k1) = []; % update delcells list
set(handles.deletelist, 'String', k2, 'Value', size(k2,1)); % update deletelist

% plot next deletelist ROI (unless it's the last ROI)
if k1 <= size(k2,1) % select the next ROI

    % ROI(s) to plot
    idx = str2num(k2(k1,:));
    handles.plot_roi = idx;

    % select the next ROI in the dellist
    set(handles.deletelist, 'String', k2, 'Value', k1);

elseif size(k2,1) == 0 % we've removed the last ROI in the deletelist

    % ROI(s) to plot -> make it ROI 1
    idx = 1;
    handles.plot_roi = idx;

elseif k1-1 == size(k2,1) % we are at the last ROI

    % ROI(s) to plot
    idx = str2num(k2(k1-1,:));
    handles.plot_roi = idx;

    % select the next ROI in the dellist
    set(handles.deletelist, 'String', k2, 'Value', k1-1);

end

% update user
set(handles.user_alert, 'String', sprintf(['Plotting ROI: ' num2str(idx)]));
pause(0.1); % make sure to update user_alert

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


% --- Executes on selection change in deletelist.
function deletelist_Callback(hObject, eventdata, handles)
% hObject    handle to deletelist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns deletelist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from deletelist

% store that we plot 1 roi
handles.to_plot = 1;

% ROI(s) to plot
% find value of roi in deletelist
k1 = get(handles.deletelist,'Value');
k2 = str2num(get(handles.deletelist,'String'));
idx = k2(k1);
handles.plot_roi = idx;

% update user
set(handles.user_alert, 'String', sprintf(['Plotting ROI: ' num2str(idx)]));
pause(0.1); % make sure to update user_alert

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MERGE ROI PAIRS

function n_pair_Callback(hObject, eventdata, handles)
% hObject    handle to n_pair (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of n_pair as text
%        str2double(get(hObject,'String')) returns contents of n_pair as a double


% --- Executes on selection change in roi1.
function roi1_Callback(hObject, eventdata, handles)
% hObject    handle to roi1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns roi1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from roi1

% % assign all ROIs to roi1
% set(handles.roi1, 'String', unique([handles.pairs_cells1 handles.pairs_cells2]));

% get current rois
if handles.to_plot ~= 2 % we're not trying to manually plot, yet
    try % we might plot a single ROI
        idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
    catch
        idx = [1 handles.plot_roi]; % just set ROI 1 on position 1
    end
else
    idx = [handles.manualpair]; % get manual ROI 1 and ROI 2 values
end

% store that we plot a manual pair
handles.to_plot = 2;

% replace one with new roi
roi_1_val = get(handles.roi1, 'Value'); % get roi1 value
idx = [roi_1_val idx(2)];
handles.manualpair = idx;

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% store data
guidata(hObject,handles);


% --- Executes on selection change in roi2.
function roi2_Callback(hObject, eventdata, handles)
% hObject    handle to roi2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns roi2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from roi2

% % assign all ROIs to roi2
% set(handles.roi2,'String',unique([handles.pairs_cells1 handles.pairs_cells2]));

% get current rois
if handles.to_plot ~= 2 % we're not trying to manually plot, yet
    try % we might plot a single ROI
        idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
    catch
        idx = [handles.plot_roi 1]; % just set ROI 1 on position 2
    end
else
    idx = [handles.manualpair]; % get manual ROI 1 and ROI 2 values
end

% store that we plot a manual pair
handles.to_plot = 2;

% replace one with new roi
roi_2_val = get(handles.roi2, 'Value'); % get roi2 value
idx = [idx(1) roi_2_val];
handles.manualpair = idx;

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% store data
guidata(hObject,handles);


% --- Executes on button press in add2merge.
function add2merge_Callback(hObject, eventdata, handles)
% hObject    handle to add2merge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% store that we plot a mergepair
handles.to_plot = 0;

% ROIs to store and plot - only pairs
% un_cells = unique([handles.pairs_cells1 handles.pairs_cells2]); % get unique pairs (cells1 and cells2 should be the same though)
% roi_1_val = un_cells(get(handles.roi1, 'Value')); % get roi1 value
% roi_2_val = un_cells(get(handles.roi2, 'Value')); % get roi2 value

% ROIs to store and plot
roi_vals = get(handles.roi1, 'Value'); % get roi1 value
roi_vals = sort([roi_vals get(handles.roi2, 'Value')], 'descend'); % get roi2 value

% update mergelist
mlist = handles.mergecells; % get mergelist
mlist = [mlist; {mat2str(roi_vals)} ]; % make updated list
set(handles.mergelist, 'String', mlist, 'Value', length(mlist)) % update list GUI
handles.mergecells = mlist; % update actual list

% ROI(s) to plot
idx = roi_vals; % ROI 1 and ROI 2

% update user
set(handles.user_alert, 'String', sprintf(['Plotting ROIs: ' num2str(idx)]));
pause(0.1); % make sure to update user_alert

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


% --- Executes on button press in pre.
function pre_Callback(hObject, eventdata, handles)
% hObject    handle to pre (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% store that we plot a mergepair
handles.to_plot = 0;

% go to the previous pair (if this was not the first pair)
if handles.pairs_currentcompare~=1

    % roi pair to plot
    handles.pairs_currentcompare = handles.pairs_currentcompare - 1;

    % ROI(s) to plot
    idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2

    % update user
    set(handles.user_alert, 'String', sprintf(['Plotting ROIs: ' num2str(idx)]));
    pause(0.1); % make sure to update user_alert

    % plot background (Cn or Mn) and ROI contours (idx)
    plot_spatial_components(handles, idx)

    % plot temporal traces of the first pair
    plot_temporal_traces(handles, idx)

    % plot ROI pair info
    plot_roi_info(handles, idx)
end

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


% --- Executes on button press in next.
function next_Callback(hObject, eventdata, handles)
% hObject    handle to next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% store that we plot a mergepair
handles.to_plot = 0;

% go to the next pair (if this was not the last pair)
if handles.pairs_currentcompare~=length(handles.pairs_cells1)

    % roi pair to plot
    handles.pairs_currentcompare = handles.pairs_currentcompare + 1;

    % ROI(s) to plot
    idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2

    % update user
    set(handles.user_alert, 'String', sprintf(['Plotting ROIs: ' num2str(idx)]));
    pause(0.1); % make sure to update user_alert

    % plot background (Cn or Mn) and ROI contours (idx)
    plot_spatial_components(handles, idx)

    % plot temporal traces of the first pair
    plot_temporal_traces(handles, idx)

    % plot ROI pair info
    plot_roi_info(handles, idx)
end

% store data
guidata(hObject,handles);


% --- Executes on button press in addlazy.
function addlazy_Callback(hObject, eventdata, handles)
% hObject    handle to addlazy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% store that we plot a mergepair
handles.to_plot = 0;

% add current pair to mergelist
tt = handles.pairs_currentcompare; % get current pair
roi_1_val = handles.pairs_cells1(tt); % cell 1
roi_2_val = handles.pairs_cells2(tt); % cell 2
m = handles.mergecells; % get all the merge pairs in mergelist
m = [m; {mat2str([roi_1_val roi_2_val])} ]; % add current pair
set(handles.mergelist, 'String', m, 'Value', length(m)) % update mergelist
handles.mergecells=m; % update matrix

% go to the next pair (if this was not the last pair)
if handles.pairs_currentcompare ~= length(handles.pairs_cells1)

    % roi pair to plot
    handles.pairs_currentcompare = handles.pairs_currentcompare + 1;

    % ROI(s) to plot
    idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2

    % plot background (Cn or Mn) and ROI contours (idx)
    plot_spatial_components(handles, idx)

    % plot temporal traces of the first pair
    plot_temporal_traces(handles, idx)

    % plot ROI pair info
    plot_roi_info(handles, idx)
    
    % update user
    set(handles.user_alert, 'String', sprintf(['Plotting ROIs: ' num2str(idx)]));
    pause(0.1); % make sure to update user_alert
end

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


function checkmergetxt_Callback(hObject, eventdata, handles)
% hObject    handle to checkmergetxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of checkmergetxt as text
%        str2double(get(hObject,'String')) returns contents of checkmergetxt as a double


% --- Executes on button press in checkmerge.
function checkmerge_Callback(hObject, eventdata, handles)
% hObject    handle to checkmerge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% get all ROIs
tmp_roi = []; % empty vector
for i = 1:length(handles.mergecells) % for each pair
    tmp_roi = [tmp_roi str2num(cell2mat(handles.mergecells(i)))]; % fill with all ROIs (roi1 and roi2's)
end
tbl = tabulate(tmp_roi);    % get frequency table of all values from min to max (include not-occuring values)
val_repeat = tbl(find(tbl(:,2)>1),1); % get repeated ROIs

% feedback user
if isempty(val_repeat)
    set(handles.checkmergetxt, 'String', sprintf(['No repeated ROIs detected -> \n          merge ROIs']));
else
    set(handles.checkmergetxt, 'String', sprintf(['Repeated ROIs detected -> \nperform multi-merge or delete ROIs:\n' num2str(val_repeat')]));
end

% % check if values are repeated
% tbl = tabulate(tmp); % frequency of values
% if ~isempty(find(tbl(:,2)>1)) % find if values (column 2) are repeated
%     repeat_vals = find(tbl(:,2)>1);
%     tmp = []; % create empty tmp var
%     for k=1:length(repeat_vals)
%         % get the value of these cells
%         if k==1
%             tmp = [ num2str( tbl(repeat_vals(k),1)) ];
%         else
%             tmp = [tmp ',' num2str( tbl(repeat_vals(k),1)) ];
%         end
%     end
%     str = sprintf(['    Repeated ROIs detected -> \nperform multi-merge or delete ROIs: \n' num2str(tmp)]);
%     set(handles.checkmergetxt,'String',str); % plot text
% else
%     set(handles.checkmergetxt, 'String', sprintf(['No repeated ROIs detected -> \n          merge ROIs']));
% end

% store data
guidata(hObject,handles);


% --- Executes on button press in multimerge.
function multimerge_Callback(hObject, eventdata, handles)
% hObject    handle to multimerge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% get all ROIs
tmp_roi = []; % empty vector
for i = 1:length(handles.mergecells) % for each pair
    tmp_roi = [tmp_roi str2num(cell2mat(handles.mergecells(i)))]; % fill with all ROIs (roi1 and roi2's)
end
tbl = tabulate(tmp_roi);    % get frequency table of all values from min to max (include not-occuring values)
val_repeat = tbl(find(tbl(:,2)>1),1); % get repeated ROIs

% examine how to multimerge
tmp_mergelist = []; % empty vector
tmp_mergelist = cell2struct(handles.mergecells, 'ids', length(handles.mergecells)); % get all pairs -> struct array with field 'ids'
idx_pairstommerge=[]; % empty vector to keep track of idx of mergelist pairs to multimerge
for i = 1:length(val_repeat) % per repeated ROI

    % check how often repeated ROI is found throughout the mergelist
    idx_tommerge = []; % empty vector to store idx of mergepairs that include repeated ROI
    for y = 1:size(tmp_mergelist,1) % per ROI
        if ~isempty(find(str2num(tmp_mergelist(y).ids) == val_repeat(i))) % check if ROI is in pair (doesn't matter position 1 or 2)
            idx_tommerge = [idx_tommerge y]; % if so, add idx of mergelist pair (index, not ROI numbers) to idx_tomerge
        end
    end

    % get absolute ROI numbers
    tmp_tommerge = []; % empty vector to keep track of multimerge ROIs
    for j = 1:length(idx_tommerge) % per mergelist pair (idx)
        tmp_tommerge = [tmp_tommerge str2num(tmp_mergelist(idx_tommerge(j)).ids)];
    end
    handles.multimergeidx(i).ids= unique(tmp_tommerge); % per repeated ROI, store absolute values of other ROIs to merge with

    % keep track of all
    idx_pairstommerge = [idx_pairstommerge idx_tommerge]; % store list in new var that includes all idx to keep and the new mergelist idx
end

% loop through multimerge values and identify the multimerge strings that are the same
idx_removemmerge = []; % empty variable for repeated multimerge strings
for k = 1:length(handles.multimergeidx) % per ROI that needs multimerge
    for q = k:length(handles.multimergeidx)
        if q~=k & isequal(handles.multimergeidx(q).ids, handles.multimergeidx(k).ids) % not check same multimerge string
            idx_removemmerge = [idx_removemmerge k]; % keep track of multimerge values that need to go (duplicates)
        end
    end
end
% delete the same multimerge strings
handles.multimergeidx(unique(idx_removemmerge)) = [];

% get full list of normal merge pairs (excl any multimerge pairs)
tmp_mergelist_array=handles.mergecells; % array with all the mergelist pairs
tmp_mergelist_array(unique(idx_pairstommerge))=[]; % remove all multimerge values

% combine all the multimerge strings with the normal merge pairs
if ~isempty(idx_pairstommerge) % make sure we have multimerge
    for k = 1:length(handles.multimergeidx) % per multimerge string
        tmp_mergelist_array = [tmp_mergelist_array; {mat2str(handles.multimergeidx(k).ids)}]; % updated array with normal and multimerge
    end
end
handles.mergecells = tmp_mergelist_array; % store all the normal merge pairs and the multimerge pairs
set(handles.mergelist, 'String', tmp_mergelist_array, 'Value', 1); % update mergelist with normal merge pairs and multimerge values

% give user feedback of which ROI values are still repeated
tmp_roi = []; % empty vector
for i = 1:length(handles.mergecells) % for each pair
    tmp_roi = [tmp_roi str2num(cell2mat(handles.mergecells(i)))]; % fill with all ROIs (roi1 and roi2's)
end
tbl = tabulate(tmp_roi);    % get frequency table of all values from min to max (include not-occuring values)
val_repeat = tbl(find(tbl(:,2)>1),1); % get repeated ROIs

% feedback user
if isempty(val_repeat)
    set(handles.checkmergetxt, 'String', sprintf(['  Multi-merge done -> \nno more repeated ROIs found']));
else
    set(handles.checkmergetxt, 'String', sprintf(['Multi-merge done -> \nmore repeated ROIs found:\n' num2str(val_repeat')]));
end

% delete rois_bad values if we plotted those
if handles.plot_bad == 1 % plot bad ROIs
    handles.rois_bad = [];
end

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


% --- Executes on button press in delete4mmerge.
function delete4mmerge_Callback(hObject, eventdata, handles)
% hObject    handle to delete4mmerge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% store that we plot a merge pair
handles.to_plot = 0;

% remove from mergelist
k1 = get(handles.mergelist, 'Value'); % get location
k2 = get(handles.mergelist, 'String'); % get total list
k2(k1,:) = []; % remove from list
handles.mergecells(k1,:) = []; % update mergecells list
set(handles.mergelist, 'String', k2, 'Value', size(k2,1)); % update mergelist

% % add current pair to mergelist
% tt = handles.pairs_currentcompare; % get current pair
% roi_1_val = handles.pairs_cells1(tt); % cell 1
% roi_2_val = handles.pairs_cells2(tt); % cell 2
% m = handles.mergecells; % get all the merge pairs in mergelist
% m = [m; {mat2str([roi_1_val roi_2_val])} ]; % add current pair
%
% tmp = k2(k1,:);

% plot next mergelist ROIs (unless it's the last pair)
if k1 <= length(k2)

    % ROI(s) to plot
    idx = str2num(cell2mat(k2(k1,:)));
    handles.plot_roi = idx;

    % select the next ROI in the dellist
    set(handles.mergelist, 'String', k2, 'Value', k1);

    % plot background (Cn or Mn) and ROI contours (idx)
    plot_spatial_components(handles, idx)

    % plot temporal traces of the first pair
    plot_temporal_traces(handles, idx)

    % plot ROI pair info
    plot_roi_info(handles, idx)

end

% update user buttons
update_button_states(handles)

% store data
guidata(hObject,handles);


% --- Executes on selection change in mergelist.
function mergelist_Callback(hObject, eventdata, handles)
% hObject    handle to mergelist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns mergelist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from mergelist

% store that we plot a mergepair
handles.to_plot = 0;

% ROI(s) to plot
k1 = get(handles.mergelist,'Value');    % location in list
k2 = get(handles.mergelist,'String');   % all pairs in list
tmp = k2(k1);   % actual roi pair
idx = str2num(cell2mat(tmp)); % values ROI1 and 2

% update user
set(handles.user_alert, 'String', sprintf(['Plotting ROIs: ' num2str(idx)]));
pause(0.1); % make sure to update user_alert

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% plot ROI pair info
plot_roi_info(handles, idx)

% store data
guidata(hObject,handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SETTINGS


function a_min_Callback(hObject, eventdata, handles)
% hObject    handle to a_min (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of a_min as text
%        str2double(get(hObject,'String')) returns contents of a_min as a double


function a_max_Callback(hObject, eventdata, handles)
% hObject    handle to a_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of a_max as text
%        str2double(get(hObject,'String')) returns contents of a_max as a double


function snr_thres_Callback(hObject, eventdata, handles)
% hObject    handle to snr_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of snr_thres as text
%        str2double(get(hObject,'String')) returns contents of snr_thres as a double


function dist_thres_Callback(hObject, eventdata, handles)
% hObject    handle to dist_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of dist_thres as text
%        str2double(get(hObject,'String')) returns contents of dist_thres as a double
% handles.distthr =  str2double(get(handles.dist_thres,'String'))


function corr_thres_Callback(hObject, eventdata, handles)
% hObject    handle to corr_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of corr_thres as text
%        str2double(get(hObject,'String')) returns contents of corr_thres as a double
% handles.corrthr =  str2double(get(handles.corr_thres,'String'))


% --- Executes on button press in check_plot_bad.
function check_plot_bad_Callback(hObject, eventdata, handles)
% hObject    handle to check_plot_bad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of check_plot_bad

% check if we allow updating plotting (i.e., have not loaded data yet)
if handles.plot_bad_update == 0 % prevent to update
    set(handles.check_plot_bad, 'Value', handles.plot_bad); % 0=good ROIs, 1=bad ROIs

    % update user
    set(handles.user_alert, 'String', sprintf('You already loaded data, cannot plot bad ROIs!'));
    pause(0.1); % make sure to update user_alert
else

    % update user
    set(handles.user_alert, 'String', sprintf('Important: only use bad ROIs on RAW output data!'));
    pause(0.1); % make sure to update user_alert
end

% --- Executes on button press in flip_bg.
function flip_bg_Callback(hObject, eventdata, handles)
% hObject    handle to flip_bg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of flip_bg

% try to plot during GUI usage
try 
% ROI(s) to plot
if handles.to_plot == 0; % plot mergepair
    idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
elseif handles.to_plot == 1; % plot single ROI
    idx = handles.plot_roi; % plot roi
elseif handles.to_plot == 2; % plot manual ROI pair
    idx = handles.manualpair;
end

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

catch; end

% store data
guidata(hObject,handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PLOTTING


function contour_thres_Callback(hObject, eventdata, handles)
% hObject    handle to contour_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of contour_thres as text
%        str2double(get(hObject,'String')) returns contents of contour_thres as a double

% update user
set(handles.user_alert, 'String', sprintf('Updating contours, please wait...'));
pause(0.1); % make sure to update user_alert

% ROI(s) to plot
if isfield(handles, 'to_plot') % check if GUI started
    if handles.to_plot == 0; % plot mergepair
        idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
    elseif handles.to_plot == 1; % plot single ROI
        idx = handles.plot_roi; % plot roi
    elseif handles.to_plot == 2; % plot manual ROI pair
        idx = handles.manualpair;
    end
else % GUI hasn't started

    % update user
    set(handles.user_alert, 'String', sprintf('Changed contours setting'));
    pause(0.1); % make sure to update

    return
end

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% update user
set(handles.user_alert, 'String', sprintf('Contours updated'));
pause(0.1); % make sure to update user_alert

% store data
guidata(hObject,handles);


function scale_cn_Callback(hObject, eventdata, handles)
% hObject    handle to scale_cn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of scale_cn as text
%        str2double(get(hObject,'String')) returns contents of scale_cn as a double

% update user
set(handles.user_alert, 'String', sprintf('Updating background, please wait...'));
pause(0.1); % make sure to update user_alert

% ROI(s) to plot
if isfield(handles, 'to_plot') % check if GUI started
    if handles.to_plot == 0; % plot mergepair
        idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
    elseif handles.to_plot == 1; % plot single ROI
        idx = handles.plot_roi; % plot roi
    elseif handles.to_plot == 2; % plot manual ROI pair
        idx = handles.manualpair;
    end
else % GUI hasn't started

    % update user
    set(handles.user_alert, 'String', sprintf('Changed background setting'));
    pause(0.1); % make sure to update

    return
end

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% % plot temporal traces of the first pair
% plot_temporal_traces(handles, idx)

% update user
set(handles.user_alert, 'String', sprintf('Background updated'));
pause(0.1); % make sure to update user_alert

% store data
guidata(hObject,handles);


% --- Executes on selection change in cn_mn_plot.
function cn_mn_plot_Callback(hObject, eventdata, handles)
% hObject    handle to cn_mn_plot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns cn_mn_plot contents as cell array
%        contents{get(hObject,'Value')} returns selected item from cn_mn_plot

% update user
set(handles.user_alert, 'String', sprintf('Updating background, please wait...'));
pause(0.1); % make sure to update user_alert

% ROI(s) to plot
if isfield(handles, 'to_plot') % check if GUI started
    if handles.to_plot == 0; % plot mergepair
        idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
    elseif handles.to_plot == 1; % plot single ROI
        idx = handles.plot_roi; % plot roi
    elseif handles.to_plot == 2; % plot manual ROI pair
        idx = handles.manualpair;
    end
else % GUI hasn't started

    % update user
    set(handles.user_alert, 'String', sprintf('Changed background setting'));
    pause(0.1); % make sure to update 

    return
end

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% % plot temporal traces of the first pair
% plot_temporal_traces(handles, idx)

% update user
set(handles.user_alert, 'String', sprintf('Background updated'));
pause(0.1); % make sure to update user_alert

% store data
guidata(hObject,handles);


% --- Executes on selection change in craw_c.
function craw_c_Callback(hObject, eventdata, handles)
% hObject    handle to craw_c (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns craw_c contents as cell array
%        contents{get(hObject,'Value')} returns selected item from craw_c

% update user
set(handles.user_alert, 'String', sprintf('Updating temporal plot, please wait...'));
pause(0.1); % make sure to update user_alert

% ROI(s) to plot
if isfield(handles, 'to_plot') % check if GUI started
    if handles.to_plot == 0; % plot mergepair
        idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
    elseif handles.to_plot == 1; % plot single ROI
        idx = handles.plot_roi; % plot roi
    elseif handles.to_plot == 2; % plot manual ROI pair
        idx = handles.manualpair;
    end
else % GUI hasn't started

    % update user
    set(handles.user_alert, 'String', sprintf('Changed temporal setting'));
    pause(0.1); % make sure to update

    return
end

% % plot background (Cn or Mn) and ROI contours (idx)
% plot_spatial_components(handles, idx)

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% update user
set(handles.user_alert, 'String', sprintf('Temporal plot updated'));
pause(0.1); % make sure to update user_alert

% store data
guidata(hObject,handles);


% --- Executes on button press in plot_rois.
function plot_rois_Callback(hObject, eventdata, handles)
% hObject    handle to plot_rois (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of plot_rois

% update user
set(handles.user_alert, 'String', sprintf('Plotting all ROIs, please wait...'));
pause(0.1); % make sure to update user_alert

% ROI(s) to plot
idx = 1:size(handles.updatedCraw,1); % all ROIs

% plot background (Cn or Mn) and ROI contours (idx)
plot_spatial_components(handles, idx)

% turn off radio button
set(handles.plot_rois, 'Value', 0);

% update user
set(handles.user_alert, 'String', sprintf('Contours of all ROIs plotted'));

function concat_mark_Callback(hObject, eventdata, handles)
% hObject    handle to concat_mark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of concat_mark as text
%        str2double(get(hObject,'String')) returns contents of concat_mark as a double

% ROI(s) to plot
if handles.to_plot == 0; % plot mergepair
    idx = [handles.pairs_cells1(handles.pairs_currentcompare) handles.pairs_cells2(handles.pairs_currentcompare)]; % ROI 1 and ROI 2
elseif handles.to_plot == 1; % plot single ROI
    idx = handles.plot_roi; % plot roi
elseif handles.to_plot == 2; % plot manual ROI pair
    idx = handles.manualpair;
end

% plot temporal traces of the first pair
plot_temporal_traces(handles, idx)

% store data
guidata(hObject,handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SINGLE ROI DATA


function roi_idx_Callback(hObject, eventdata, handles)
% hObject    handle to roi_idx (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of roi_idx as text
%        str2double(get(hObject,'String')) returns contents of roi_idx as a double


function n_rois_Callback(hObject, eventdata, handles)
% hObject    handle to n_rois (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of n_rois as text
%        str2double(get(hObject,'String')) returns contents of n_rois as a double


function roi_snr_Callback(hObject, eventdata, handles)
% hObject    handle to roi_snr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of roi_snr as text
%        str2double(get(hObject,'String')) returns contents of roi_snr as a double


function roi_size_Callback(hObject, eventdata, handles)
% hObject    handle to roi_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of roi_size as text
%        str2double(get(hObject,'String')) returns contents of roi_size as a double


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ROI PAIR DATA


function cell_pair1_Callback(hObject, eventdata, handles)
% hObject    handle to cell_pair1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cell_pair1 as text
%        str2double(get(hObject,'String')) returns contents of cell_pair1 as a double


function cell_pair_dist_Callback(hObject, eventdata, handles)
% hObject    handle to cell_pair_dist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cell_pair_dist as text
%        str2double(get(hObject,'String')) returns contents of cell_pair_dist as a double


function cell_pair2_Callback(hObject, eventdata, handles)
% hObject    handle to cell_pair2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cell_pair2 as text
%        str2double(get(hObject,'String')) returns contents of cell_pair2 as a double


function cell_pair_corr_Callback(hObject, eventdata, handles)
% hObject    handle to cell_pair_corr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cell_pair_corr as text
%        str2double(get(hObject,'String')) returns contents of cell_pair_corr as a double


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CREATE PLOT PANELS


% --- Executes during object creation, after setting all properties.
function distcorr_CreateFcn(hObject, eventdata, handles)
% hObject    handle to distcorr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate distcorr


% --- Executes during object creation, after setting all properties.
function histsnr_CreateFcn(hObject, eventdata, handles)
% hObject    handle to histsnr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate histsnr


% --- Executes during object creation, after setting all properties.
function ax1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ax1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate ax1


% --- Executes during object creation, after setting all properties.
function ax2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ax2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate ax2


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CREATE ALL OTHER OBJECTS


% --- Executes during object creation, after setting all properties.
function roi1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function roi2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function dist_thres_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dist_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function corr_thres_CreateFcn(hObject, eventdata, handles)
% hObject    handle to corr_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function contour_thres_CreateFcn(hObject, eventdata, handles)
% hObject    handle to contour_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function snr_thres_CreateFcn(hObject, eventdata, handles)
% hObject    handle to snr_thres (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function deletelist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deletelist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function celllist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to celllist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function add2dellist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to add2dellist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function slidertoaddtodellist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slidertoaddtodellist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function mergelist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to mergelist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');mlist
end


% --- Executes during object creation, after setting all properties.
function checkmerge_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkmerge (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function checkmergetxt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to checkmergetxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function id_CreateFcn(hObject, eventdata, handles)
% hObject    handle to id (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function scale_cn_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scale_cn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function cn_mn_plot_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cn_mn_plot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function cell_pair1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cell_pair1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function cell_pair_dist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cell_pair_dist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function cell_pair2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cell_pair2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function cell_pair_corr_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cell_pair_corr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function roi_idx_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi_idx (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function roi_snr_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi_snr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on key press with focus on mergelist and none of its controls.
function mergelist_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to mergelist (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes during object creation, after setting all properties.
function craw_c_CreateFcn(hObject, eventdata, handles)
% hObject    handle to craw_c (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function n_rois_CreateFcn(hObject, eventdata, handles)
% hObject    handle to n_rois (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function user_alert_CreateFcn(hObject, eventdata, handles)
% hObject    handle to user_alert (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function a_min_CreateFcn(hObject, eventdata, handles)
% hObject    handle to a_min (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function a_max_CreateFcn(hObject, eventdata, handles)
% hObject    handle to a_max (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function roi_size_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function n_pair_CreateFcn(hObject, eventdata, handles)
% hObject    handle to n_pair (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function text_sizehisto_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text_sizehisto (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function histsize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to histsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate histsize


% --- Executes during object creation, after setting all properties.
function concat_mark_CreateFcn(hObject, eventdata, handles)
% hObject    handle to concat_mark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ALL FUNCTIONS


function [snr] = get_SNR(dataC, dataCraw)
% Estimate per-ROI SNR as (transient amplitude) / noise, in units of noise
% std. Peaks are located on the denoised trace C, their amplitude read from
% the raw trace C_raw, and noise/baseline estimated from the peak-free C_raw.
% inputs:
%   dataC    = denoised traces [nROI x T] (used to locate peaks)
%   dataCraw = raw traces      [nROI x T] (used for amplitude and noise)
%
% Amplitude = (C_raw peak) - (F0, a low percentile of the peak-free trace);
% noise = MAD-based robust std of the peak-free trace. The reported SNR is
% the MEDIAN over PROMINENT transients only - peaks whose amplitude exceeds
% promFactor x noise. Restricting to prominent transients stops the many
% small noise-wiggle maxima from dragging the median down (which made the
% old "median over every local maximum" value read too low). Subtracting F0
% before dividing by a robust noise makes the metric comparable across
% toolboxes regardless of each one's absolute trace offset/scale (important
% for Suite2P, whose C_raw = F - 0.7*Fneu keeps the resting offset).
%
% Toolbox-free: uses find_local_maxima (below) instead of findpeaks, and
% local_prctile / median(...,'omitnan') instead of prctile / nanmedian, so
% no Signal Processing or Statistics Toolbox license is required.

% fixed vars
windowCraw       = 5;  % window before a C peak to find the C_raw peak
windowCrawRemove = 2;  % half-window around each C_raw peak removed for baseline
baselinePercentile = 8;% low percentile of the peak-free trace used as F0
promFactor       = 3;  % a transient is "prominent" if amplitude >= this x noise

nROI = size(dataC,1);
snr  = nan(1, nROI);
for k = 1:nROI

    baseline = dataCraw(k,:);              % becomes the peak-free trace below
    loc = find_local_maxima(dataC(k,:));   % peaks in denoised C (no toolbox)
    if isempty(loc), snr(k) = nan; continue; end

    locOn  = max(loc - windowCraw, 1);     % look back in time in C_raw
    locOff = loc;

    % read each peak's amplitude in C_raw and blank its window in baseline
    max_val = zeros(1, numel(loc));
    for kk = 1:numel(loc)
        [mv, mi] = max(dataCraw(k, locOn(kk):locOff(kk)));
        max_val(kk) = mv;
        aidx = mi + locOn(kk) - 1;
        lo = max(aidx - windowCrawRemove, 1);
        hi = min(aidx + windowCrawRemove, numel(baseline));
        baseline(lo:hi) = nan;
    end

    baseline_level = local_prctile(baseline, baselinePercentile);       % F0
    noise_std      = 1.4826 * median(abs(baseline - median(baseline,'omitnan')), 'omitnan'); % robust std
    if ~(noise_std > 0), snr(k) = nan; continue; end

    amp  = max_val - baseline_level;              % per-transient amplitude over F0
    kept = amp(amp >= promFactor * noise_std);    % prominent transients only
    if isempty(kept), kept = amp; end             % fall back to all if none pass
    snr(k) = median(kept) / noise_std;
end


function loc = find_local_maxima(x)
% Indices of strict interior local maxima: x(i) > x(i-1) and x(i) > x(i+1).
% Toolbox-free replacement for findpeaks with default options.
x = x(:)';
if numel(x) < 3, loc = []; return; end
d = diff(x);
loc = find(d(1:end-1) > 0 & d(2:end) < 0) + 1;


function y = local_prctile(v, p)
% Percentile p (0-100) of v ignoring NaNs, matching MATLAB prctile's
% midpoint convention with linear interpolation. Toolbox-free.
v = sort(v(~isnan(v)));
if isempty(v),   y = NaN;  return; end
if isscalar(v),  y = v(1); return; end
n = numel(v);
q = (0.5:1:(n-0.5)) / n * 100;      % plotting positions of the sorted data
y = interp1(q, v, p, 'linear');
if isnan(y), if p <= q(1), y = v(1); else, y = v(end); end; end  % clamp ends


function plot_temporal_traces(handles, idx)
% plot temporal components in ax1

% fixed vars
fraction_yrange = .05;   % fraction of data to plot above/below figure

% check if we want to plot Craw or C
plot_ccraw = get(handles.craw_c, 'Value');

% plot Craw or C
min_val = []; % keep track of min val y axis
max_val = []; % keep track of max val y axis
axes(handles.ax1);
if plot_ccraw == 1 % C_raw

    % identify 1 ROI, 2 ROIs, or anything else (multi-merge)
    if length(idx) == 1 % one ROI
        plot(handles.ax1, handles.updatedCraw(idx, :), 'Color', handles.colors(1,:));
        min_val = min(handles.updatedCraw(idx, :));
        max_val = max(handles.updatedCraw(idx, :));
    elseif length(idx) == 2 % 2 ROIs
        % plot per ROI
        for k = 1:length(idx)
            plot(handles.ax1, handles.updatedCraw(idx(k), :), 'Color', handles.colors(k+1,:));
            hold(handles.ax1,'on')
            min_val = [min_val min(handles.updatedCraw(idx(k), :))];
            max_val = [max_val max(handles.updatedCraw(idx(k), :))];
        end
        hold(handles.ax1,'off')
    else % many ROIs multi-merge
        % plot per ROI
        cmap = parula(length(idx));
        for k = 1:length(idx)
            plot(handles.ax1, handles.updatedCraw(idx(k), :), 'Color', cmap(k,:));
            hold(handles.ax1,'on')
            min_val = [min_val min(handles.updatedCraw(idx(k), :))];
            max_val = [max_val max(handles.updatedCraw(idx(k), :))];
        end
        hold(handles.ax1,'off')
    end

    % define y lims
    try
        change_y = (max(max_val) - min(min_val)) * fraction_yrange;
        ylim([min(min_val)-change_y max(max_val)+change_y])
    catch end % in case of a rois_bad, signal can be 0

    % define x lims
    xlim([1 size(handles.updatedCraw,2)])

else % plot C

    % identify 1 ROI, 2 ROIs, or anything else (multi-merge)
    if length(idx) == 1 % one ROI
        plot(handles.ax1, handles.updatedC(idx, :), 'Color', handles.colors(1,:));
        min_val = min(handles.updatedC(idx, :));
        max_val = max(handles.updatedC(idx, :));
    elseif length(idx) == 2 % 2 ROIs
        % plot per ROI
        for k = 1:length(idx)
            plot(handles.ax1, handles.updatedC(idx(k), :), 'Color', handles.colors(k+1,:));
            hold(handles.ax1,'on')
            min_val = [min_val min(handles.updatedC(idx(k), :))];
            max_val = [max_val max(handles.updatedC(idx(k), :))];
        end
        hold(handles.ax1,'off')
    else % many ROIs multi-merge
        % plot per ROI
        cmap = parula(length(idx));
        for k = 1:length(idx)
            plot(handles.ax1, handles.updatedC(idx(k), :), 'Color', cmap(k,:));
            hold(handles.ax1,'on')
            min_val = [min_val min(handles.updatedC(idx(k), :))];
            max_val = [max_val max(handles.updatedC(idx(k), :))];
        end
        hold(handles.ax1,'off')
    end

    % define y lims
    try
        change_y = (max(max_val) - min(min_val)) * fraction_yrange;
        ylim([min(min_val)-change_y max(max_val)+change_y])
    catch end

    % define x lims
    xlim([1 size(handles.updatedCraw,2)])

end

% plot concatenate marks
concat_mark =  str2num(get(handles.concat_mark,'String')); % get concatenation marks
concat_tmp = [concat_mark : concat_mark : size(handles.updatedCraw,2)]; % make vector
hold(handles.ax1,'on')
for k=1:length(concat_tmp) % plot per mark
    plot(handles.ax1, [concat_tmp(k) concat_tmp(k)], [min(min_val) max(max_val)], ":", 'Color', 'k'); % [min(min_val) min(min_val)], "."
end
hold(handles.ax1,'off')


function plot_spatial_components(handles, idx, highlight)
% plot background (Cn or Mn) and spatial components in ax2
%
% - idx of length 1: a single ROI (e.g. del-list browsing, or a
%   click-selected ROI passed in via the optional 3rd arg 'highlight')
% - idx of length 2: a merge pair
% - idx spanning (almost) all ROIs with no highlight: the "Plot all
%   ROIs" button - a one-off, brightly colored view of every ROI
%
% every case except "Plot all ROIs" shares one persistent dim-green
% background contour for every ROI (built once and reused - see
% ensure_roi_background), with only the current view's ROI(s) recolored
% bright on top (see apply_roi_view). Nothing gets redrawn or
% recomputed just to switch which ROI(s) are being viewed, which is what
% used to make clicking/browsing slow with many ROIs.

if nargin < 3
    highlight = [];
end

if isempty(highlight) && length(idx) > 2
    % "Plot all ROIs" button: bypass the persistent dim background
    % entirely for a one-off, colorful view of everything
    plot_all_rois_rainbow(handles, idx);
    return
end

if ~isempty(highlight)
    idx = highlight; % click-selecting one ROI looks exactly like viewing it alone
end

ensure_roi_background(handles);
apply_roi_view(handles, idx);

% remove labels
set(handles.ax2, 'XTick', [], 'YTick', []);

% make everything in ax2 transparent to mouse clicks: by default these
% objects have HitTest='on', so a click lands on them (not the axes) and
% is silently swallowed since they have no ButtonDownFcn of their own -
% this is why ax2's ButtonDownFcn would never fire otherwise
set(allchild(handles.ax2), 'HitTest', 'off', 'PickableParts', 'none');

% re-apply click-to-select every time: a fresh background redraw resets
% axes properties, which would otherwise silently wipe out the
% ButtonDownFcn and the disabled default interactivity set up in
% start_gui_Callback
disableDefaultInteractivity(handles.ax2);
set(handles.ax2, 'ButtonDownFcn', {@ax2_ButtonDownFcn, handles.figure1});


function [data, clim_vals] = compute_background_image_data(handles)
% compute the Cn/Mn image data and color axis limits to display, based
% on the current display settings (cn/mn toggle, flip, scale). Shared by
% draw_background_image (fresh draw) and ensure_roi_background (in-place
% update), so scale/Cn-Mn/flip changes never require redrawing anything
% else in ax2 - see ensure_roi_background.

c_lim_reduction =  str2num(get(handles.scale_cn,'String'));
plot_cn_mn = get(handles.cn_mn_plot,'Value');

if plot_cn_mn == 1 % plot Cn
    flip_bg = get(handles.flip_bg, 'Value'); % 0=no flip, 1=flip
    if flip_bg == 0
        data = fliplr(rot90(handles.rawdata1.results.Cn, -1));
    else
        data = handles.rawdata1.results.Cn;
    end
    tmp_max = ( min(min(handles.rawdata1.results.Cn)) + ((max(max(handles.rawdata1.results.Cn)) - min(min(handles.rawdata1.results.Cn))) / c_lim_reduction) );
    clim_vals = [ min(min(handles.rawdata1.results.Cn)) + ((tmp_max - min(min(handles.rawdata1.results.Cn))) / 2) tmp_max];
elseif plot_cn_mn == 2 % plot Mn
    if ~isfield(handles.rawdata1.results, 'Mn') % fall back to Cn if Mn unavailable
        set(handles.cn_mn_plot, 'Value', 1); % reset toggle to Cn
        set(handles.user_alert, 'String', 'Mn not available, showing Cn');
        flip_bg = get(handles.flip_bg, 'Value');
        if flip_bg == 0
            data = fliplr(rot90(handles.rawdata1.results.Cn, -1));
        else
            data = handles.rawdata1.results.Cn;
        end
        tmp_max = ( min(min(handles.rawdata1.results.Cn)) + ((max(max(handles.rawdata1.results.Cn)) - min(min(handles.rawdata1.results.Cn))) / c_lim_reduction) );
        clim_vals = [ min(min(handles.rawdata1.results.Cn)) + ((tmp_max - min(min(handles.rawdata1.results.Cn))) / 2) tmp_max];
    else
        flip_bg = get(handles.flip_bg, 'Value');
        if flip_bg == 0
            data = fliplr(rot90(handles.rawdata1.results.Mn, -1));
        else
            data = handles.rawdata1.results.Mn;
        end
        clim_vals = [min(min(handles.rawdata1.results.Mn)) ...
            ( min(min(handles.rawdata1.results.Mn)) + ((max(max(handles.rawdata1.results.Mn)) - min(min(handles.rawdata1.results.Mn))) / c_lim_reduction) )];
    end
end


function img_handle = draw_background_image(handles)
% draw the Cn/Mn background image fresh into ax2 (currently-selected
% axes) and return its handle; used when there's nothing to update in
% place (no cache yet) and by plot_all_rois_rainbow (which always fully
% redraws anyway)

[data, clim_vals] = compute_background_image_data(handles);
img_handle = imagesc(data);
clim(clim_vals);
colormap gray;


function key = roi_image_key(handles)
% settings that affect only the background image - changing these can
% be handled with an in-place CData/CLim update, no redraw needed
key = struct( ...
    'cn_mn', get(handles.cn_mn_plot,'Value'), ...
    'flip_bg', get(handles.flip_bg,'Value'), ...
    'scale_cn', str2num(get(handles.scale_cn,'String')));


function key = roi_contour_key(handles)
% settings that affect the ROI contours - changing these requires
% deleting and rebuilding the contour objects (but not the image)
key = struct( ...
    'n_rois', size(handles.Afull,1), ...
    'thres', str2num(get(handles.contour_thres,'String')));


function contour_handles = build_all_roi_contours(handles, contour_key)

% draw one dim green contour per ROI directly into ax2, regardless of
% current-axes/hold state (see ensure_roi_background)
n_rois = contour_key.n_rois;
contour_handles = gobjects(1, n_rois);

for k = 1:n_rois
    roiImage = squeeze(handles.Afull(k,:,:));
    tmp_thres = min(roiImage(:)) + ((max(roiImage(:)) - min(roiImage(:))) * (1 - contour_key.thres));
    [~, h] = contour(handles.ax2, roiImage, [tmp_thres tmp_thres], 'LineWidth', 1.5, 'LineColor', handles.colors(4,:), 'EdgeAlpha', 0.5);
    contour_handles(k) = h;
end


function ensure_roi_background(handles)
% draw the background image and a dim green contour for every ROI once,
% caching them in ax2's appdata so single-ROI, merge-pair, and
% click-select views can all reuse them (see apply_roi_view) instead of
% redrawing everything on every view change. Image-only settings (Cn/Mn
% toggle, flip, scale) update the existing image's CData/CLim in place
% without touching the contours at all; ROI-count/threshold changes only
% rebuild the contours, leaving the image alone. Everything is only
% drawn from scratch when there's no usable cache yet (e.g. right after
% "Plot all ROIs", which wipes the axes).

img_key = roi_image_key(handles);
contour_key = roi_contour_key(handles);
cache = getappdata(handles.ax2, 'roi_bg_cache');

if isempty(cache) || ~isgraphics(cache.img_handle)
    % nothing usable to update in place - draw everything from scratch
    axes(handles.ax2);
    img_handle = draw_background_image(handles);
    hold(handles.ax2, 'on');
    contour_handles = build_all_roi_contours(handles, contour_key);
    hold(handles.ax2, 'off');
    active = [];
else
    img_handle = cache.img_handle;
    contour_handles = cache.contour_handles;
    active = cache.active;

    if ~isequal(cache.img_key, img_key)
        % only the image needs updating - set CData/CLim in place; this
        % does NOT clear the axes, so the contour objects on top are
        % left completely untouched
        [data, clim_vals] = compute_background_image_data(handles);
        set(img_handle, 'CData', data);
        clim(handles.ax2, clim_vals);
    end

    if ~isequal(cache.contour_key, contour_key) || ~all(isgraphics(contour_handles))
        % ROI count or contour threshold changed - delete and rebuild
        % just the contours; the background image is left alone
        delete(contour_handles(isgraphics(contour_handles)));
        hold(handles.ax2, 'on');
        contour_handles = build_all_roi_contours(handles, contour_key);
        hold(handles.ax2, 'off');
        active = []; % the old highlight doesn't apply to the new objects
    end
end

setappdata(handles.ax2, 'roi_bg_cache', struct( ...
    'img_handle', img_handle, 'img_key', img_key, ...
    'contour_handles', {contour_handles}, 'contour_key', contour_key, ...
    'active', active));


function apply_roi_view(handles, idx)
% recolor the persistent background contours (see ensure_roi_background)
% so idx's ROI(s) are shown bright and everything else stays dimmed.
% Never redraws or recomputes a contour - just restyles existing
% objects - so switching views is instant regardless of ROI count.

cache = getappdata(handles.ax2, 'roi_bg_cache');

% dim whatever was previously the active view
for k = 1:numel(cache.active)
    roi = cache.active(k);
    if roi >= 1 && roi <= numel(cache.contour_handles) && isgraphics(cache.contour_handles(roi))
        set(cache.contour_handles(roi), 'LineWidth', 1.5, 'LineColor', handles.colors(4,:), 'EdgeAlpha', 0.5);
    end
end

% brighten the current view's ROI(s)
if length(idx) == 1 % single ROI (del-list view or click-selected)
    set(cache.contour_handles(idx(1)), 'LineWidth', 3, 'LineColor', handles.colors(1,:), 'EdgeAlpha', 1);
elseif length(idx) == 2 % merge pair
    for k = 1:2
        set(cache.contour_handles(idx(k)), 'LineWidth', 1.5, 'LineColor', handles.colors(k+1,:), 'EdgeAlpha', 1);
    end
end

cache.active = idx;
setappdata(handles.ax2, 'roi_bg_cache', cache);


function plot_all_rois_rainbow(handles, idx)
% "Plot all ROIs" button: a one-off, brightly colored view of every ROI
% at once (parula colormap per ROI), independent of the persistent dim
% background used everywhere else (see ensure_roi_background)

axes(handles.ax2);
draw_background_image(handles);
hold(handles.ax2, 'on');

cmap = parula(length(idx));
for k = 1:length(idx)
    roiImage = squeeze(handles.Afull(idx(k),:,:));
    tmp_thres = min(min(roiImage)) + ((max(max(roiImage)) - min(min(roiImage))) * (1 - str2num(get(handles.contour_thres,'String'))) );
    contour(roiImage, [tmp_thres tmp_thres], 'LineWidth', 1.5, 'LineColor', cmap(k,:));
end
hold(handles.ax2, 'off');

% this redraw just destroyed whatever was cached - invalidate it so the
% next normal view (single ROI / pair / click-select) rebuilds the dim
% background fresh instead of reusing now-deleted graphics handles
setappdata(handles.ax2, 'roi_bg_cache', []);

set(handles.ax2, 'XTick', [], 'YTick', []);
set(allchild(handles.ax2), 'HitTest', 'off', 'PickableParts', 'none');
disableDefaultInteractivity(handles.ax2);
set(handles.ax2, 'ButtonDownFcn', {@ax2_ButtonDownFcn, handles.figure1});


function ax2_ButtonDownFcn(hObject, eventdata, guiFig)
% fires when the user clicks anywhere in ax2 (background/contour axes)
% selects the ROI under the click, highlights it among all contours,
% shows its trace in ax1, and updates the ROI info text (roi_idx/SNR/size)

handles = guidata(guiFig);

% ignore clicks before data has been loaded/started
if ~isfield(handles, 'Afull') || isempty(handles.Afull)
    return
end

% update user
set(handles.user_alert, 'String', sprintf('Loading selected ROI...'));
pause(0.1);

% click location in the same pixel coordinates as handles.Afull
pt = get(handles.ax2, 'CurrentPoint');
col = round(pt(1,1));
row = round(pt(1,2));

% (re)build the pixel->ROI lookup map if it's missing or stale (i.e. the
% contour threshold changed since it was built). This used to be redone
% from scratch on every single click - looping over every ROI and
% rescanning the whole image just to test one pixel - which is what made
% clicking slow with many ROIs. Now it's cached and only rebuilt when
% the threshold that defines the ROI outlines actually changes.
% the lookup is also stale if the ROI set itself changed (delete/merge),
% not just when the contour threshold changed - check both
contour_frac = str2num(get(handles.contour_thres,'String'));
n_rois_now = size(handles.Afull, 1);
if ~isfield(handles, 'roi_label_map') || ~isfield(handles, 'roi_label_map_thres') || ...
        ~isfield(handles, 'roi_label_map_n') || handles.roi_label_map_thres ~= contour_frac || ...
        handles.roi_label_map_n ~= n_rois_now
    handles = build_roi_lookup(handles, contour_frac);
    guidata(guiFig, handles);
end

% find which ROI (if any) was clicked
roi = find_roi_at_point(handles, row, col);
if isempty(roi)
    return % click missed every ROI
end

% store as the "active" ROI - same field the delete-list flow uses, so
% add2dellist_Callback etc. work on it unchanged
handles.plot_roi = roi;
handles.to_plot = 1;

% highlight this ROI against the persistent dim background - just
% re-colors two contour objects (see apply_roi_view), no redraw at all
plot_spatial_components(handles, roi)

% show its trace and update the ROI info text
plot_temporal_traces(handles, roi)
plot_roi_info(handles, roi)

% keep the delete-list slider in sync
set(handles.slidertoaddtodellist, 'Value', roi)

% update user
set(handles.user_alert, 'String', sprintf('Manually selected ROI: %d', roi));
pause(0.1);

% store data
guidata(guiFig, handles)


function handles = build_roi_lookup(handles, contour_frac)
% precompute, once, a pixel->ROI lookup map (which ROI, if any, "owns"
% each pixel at the current contour threshold) so find_roi_at_point can
% do an O(1) lookup instead of looping over every ROI and rescanning the
% whole image on every click. Rebuilt only when contour_frac or the
% number of ROIs (i.e. after a delete/merge) changes - see caller.

n_rois = size(handles.Afull, 1);
d1 = size(handles.Afull, 2);
d2 = size(handles.Afull, 3);

label_map = zeros(d1, d2);   % 0 = no ROI claims this pixel
size_map = inf(d1, d2);      % size (in pixels) of the ROI currently claiming it

for k = 1:n_rois
    roiImage = squeeze(handles.Afull(k,:,:));
    tmp_thres = min(roiImage(:)) + ((max(roiImage(:)) - min(roiImage(:))) * (1 - contour_frac));
    mask = roiImage >= tmp_thres;
    % overlapping ROIs: keep the smallest (most specific), same
    % tie-break as the old per-click loop
    claim = mask & (handles.pixels_A(k) < size_map);
    label_map(claim) = k;
    size_map(claim) = handles.pixels_A(k);
end

handles.roi_label_map = label_map;
handles.roi_label_map_thres = contour_frac;
handles.roi_label_map_n = n_rois;


function roi_idx = find_roi_at_point(handles, row, col)
% find which ROI mask covers pixel (row,col) using the precomputed
% roi_label_map (see build_roi_lookup); falls back to the nearest ROI
% centroid (handles.Cent_N) if the click is a near miss; returns empty
% if nothing is close enough

roi_idx = [];
d1 = size(handles.roi_label_map, 1);
d2 = size(handles.roi_label_map, 2);

if row < 1 || row > d1 || col < 1 || col > d2
    return % click was outside the image entirely
end

hit = handles.roi_label_map(row, col);
if hit > 0
    roi_idx = hit;
elseif isfield(handles, 'Cent_N') && ~isempty(handles.Cent_N)
    % no direct hit: fall back to nearest centroid within a small radius
    dists = sqrt((handles.Cent_N(:,1) - row).^2 + (handles.Cent_N(:,2) - col).^2);
    [mind, tmp] = min(dists);
    if mind <= 15 % pixels
        roi_idx = tmp;
    end
end


function plot_roi_info(handles, idx)
% plot info regarding ROIs
% 1 ROI: update roi index and SNR
% 2 ROIs: roi indices, dist and corr, and dist vs corr plot (ax3)

% figure out how many ROIs
if length(idx) == 1 % 1 roi
    % display roi index and SNR value
    set(handles.roi_idx, 'String', sprintf('%d', idx));
    set(handles.roi_snr, 'String', sprintf('%.1f', handles.SNR(idx)));
    set(handles.roi_size, 'String', sprintf('%.0f', handles.pixels_A(idx)));

    % update user
    set(handles.user_alert, 'String', sprintf(['Plotting ROI: ' num2str(idx)]));
    pause(0.1); % make sure to update user_alert

else % more ROIs
    % plot cell identity
    set(handles.cell_pair1, 'String', sprintf('%d', idx(1)));
    set(handles.cell_pair2, 'String', sprintf('%d', idx(2)));

    % if we plot a manual pair, sort idx to make high value roi 1
    if handles.to_plot == 2 % manual merge pair
        idx = sort(idx, 'descend');
    end

    % plot cell pair info
    set(handles.cell_pair_dist, 'String', sprintf('%.1f', handles.dist_mat(idx(1), idx(2))));
    set(handles.cell_pair_corr, 'String', sprintf('%.1f', handles.corr_mat(idx(1), idx(2))));

    % plot distance vs crosscorr: current pair. Re-use a single marker
    % handle (stashed in the axes' appdata) instead of calling plot()
    % again each time - a fresh plot() call with hold left 'off' would
    % wipe the full background scatter instead of just moving the dot
    pair_marker = getappdata(handles.distcorr, 'pair_marker');
    if isempty(pair_marker) || ~isvalid(pair_marker)
        hold(handles.distcorr, 'on');
        pair_marker = plot(handles.distcorr, handles.dist_mat(idx(1), idx(2)), handles.corr_mat(idx(1), idx(2)), '.', 'Color', handles.color_plots(2,:), 'LineStyle', 'none', 'MarkerSize', 20);
        setappdata(handles.distcorr, 'pair_marker', pair_marker);
    else
        set(pair_marker, 'XData', handles.dist_mat(idx(1), idx(2)), 'YData', handles.corr_mat(idx(1), idx(2)));
    end
    % this marker is created before the full scatter (start_gui_Callback
    % calls plot_roi_info before it draws the scatter), so by default it
    % sits underneath every scatter dot added afterward and stays there -
    % force it back to the top of the stack every time so it's visible
    uistack(pair_marker, 'top');
end


function output = load_cnmf_hdf5(filename1, filepath1, handles);
% load raw hdf5 output of cnmf (caiman)
% store data so that the GUI can use it
% keep a .raw with all the data (good/bad rois, settings, etc)

% identify structure and database
metadata = h5info([filepath1 filename1]); % read file
data_nm = metadata.Groups(1).Name;
options_nm = metadata.Groups(2).Name;

% create struct to load data
output = struct;

% load the data to generate sparse matrix for contours (A)
data = h5read([filepath1 filename1], '/estimates/A/data');
indices = h5read([filepath1 filename1], '/estimates/A/indices') + 1; % MATLAB is 1-based
indptr = h5read([filepath1 filename1], '/estimates/A/indptr') + 1; % MATLAB is 1-based
shape = h5read([filepath1 filename1], '/estimates/A/shape');

% reconstruct the sparse matrix
nRows = double(shape(1));
nCols = double(shape(2));
row_indices = [];
col_indices = [];
values = [];

% generate values for matrix
for col = 1:nCols
    start_idx = indptr(col);
    end_idx = indptr(col+1) - 1;
    row_indices = [row_indices; indices(start_idx:end_idx)];
    col_indices = [col_indices; double(col) * ones(end_idx - start_idx + 1, 1)]; % explicitly cast col to double
    values = [values; data(start_idx:end_idx)];
end

% ensure values are double as well
row_indices = double(row_indices);
col_indices = double(col_indices);
values = double(values);

% create the sparse matrix
A = sparse(row_indices, col_indices, values, nRows, nCols);

% find cnmf (caiman) data
% C, Cn, F_dff, R, S, SNR_comp, YrA, bl, c1, g, idx_components,
% idx_components_bad, lam, neurons_sn, r_values, data_nm
C_raw = h5read([filepath1 filename1], [data_nm '/F_dff'])';
C = h5read([filepath1 filename1], [data_nm '/C'])';
S = h5read([filepath1 filename1], [data_nm '/S'])';
spat_bgnd_comp = h5read([filepath1 filename1], [data_nm '/b']);
temp_bgnd_comp = h5read([filepath1 filename1], [data_nm '/f']);
rois_good = h5read([filepath1 filename1], [data_nm '/idx_components']) +1; % MATLAB is 1-based
rois_bad = h5read([filepath1 filename1], [data_nm '/idx_components_bad']) +1; % MATLAB is 1-based
rois_bad = rois_bad'; %
try % not everyone has these vars
    residuals = h5read([filepath1 filename1], [data_nm '/YrA'])';
    tmp = h5read([filepath1 filename1], [data_nm '/neurons_sn']); % get SNR
    for k=1:length(tmp)
        SNR(k,1) = str2num(tmp(k));
    end
catch end

% store raw rois
output.raw.C_raw = C_raw;
output.raw.C = C;
output.raw.S = S;
output.raw.A = A;
output.raw.spat_bgnd_comp = spat_bgnd_comp;
output.raw.temp_bgnd_comp = temp_bgnd_comp;
try % not everyone has these vars
    output.raw.residuals = residuals;
    output.raw.SNR_cnmf = SNR;
catch end
output.raw.rois_good = rois_good;
output.raw.rois_bad = rois_bad;

% try to include motion correction shifts
try % not everyone has the (pw)rigid movements
    output.raw_correlations = h5read([filepath1 filename1], [options_nm '/raw_corrs']);
    output.rigid_correlations = h5read([filepath1 filename1], [options_nm '/rigid_corrs']);
    output.rigid_shifts = h5read([filepath1 filename1], [options_nm '/rigid_shifts']);
    output.pwrigid_shifts = h5read([filepath1 filename1], [options_nm '/pwrigid_shifts']);
catch end

% store good or all ROIs -> if all, the bad ROIs go into delete list
% native_index maps each working ROI back to its component index in the
% original .hdf5, so save can copy-and-patch a native file (see patch_hdf5)
if isequal(rois_good, rois_bad') % user decided to discard all the bad rois
    % store only the good rois
    output.C_raw = C_raw(:, :);
    output.C = C(:, :);
    output.S = S(:, :);
    output.A = A(:, :);
    try % not everyone has these vars
        output.residuals = residuals(:, :);
        output.SNR_cnmf = SNR(:, :);
    catch end
    output.native_index = 1:size(C_raw,1);
elseif handles.plot_bad == 0 % only good ROIs
    % store only the good rois
    output.C_raw = C_raw(rois_good, :);
    output.C = C(rois_good, :);
    output.S = S(rois_good, :);
    output.A = A(:, rois_good);
    try % not everyone has these vars
        output.residuals = residuals(rois_good, :);
        output.SNR_cnmf = SNR(rois_good, :);
    catch end
    output.native_index = rois_good;
elseif handles.plot_bad == 1 % all ROIs (good and bad)
    % store all the ROIs
    output.C_raw = C_raw(:, :);
    output.C = C(:, :);
    output.S = S(:, :);
    output.A = A(:, :);
    try % not everyone has these vars
        output.residuals = residuals(:, :);
        output.SNR_cnmf = SNR(:, :);
    catch end
    output.rois_bad = rois_bad;
    output.native_index = 1:size(C_raw,1);
end

% store images
output.Cn = h5read([filepath1 filename1], [data_nm '/Cn']);   % correlation image
try % not everyone has Mn
    output.Mn = h5read([filepath1 filename1], [data_nm '/Mn']);   % max projection
    output.Cn_ori = h5read([filepath1 filename1], [data_nm '/Cn_ori']);   % correlation image original
    output.Mn_ori = h5read([filepath1 filename1], [data_nm '/Mn_ori']);   % max projection original
catch end

% store cnmf (caiman) settings
output.settings.pipeline = 'cnmf';
output.settings.fps = h5read([filepath1 filename1], [options_nm '/data/fr']);
output.settings.dims = h5read([filepath1 filename1], [options_nm '/data/dims']);
output.settings.d1 = output.settings.dims(1);
output.settings.d2 = output.settings.dims(2);
output.settings.decay_time = h5read([filepath1 filename1], [options_nm '/data/decay_time']);
output.settings.fnames = h5read([filepath1 filename1], [options_nm '/data/fnames']);
output.settings.dxy = h5read([filepath1 filename1], [options_nm '/data/dxy']);


function [center, pixels, A_full] = get_shape_size_A(handles)
% get shape of all ROIs, find center of mass, and find number of pixels

% get shape of ROIs A
A_full = reshape(full(handles.updatedA)', size(handles.updatedCraw,1), handles.rawdata1.results.settings.d1, handles.rawdata1.results.settings.d2);

% loop through cells to calculate center of mass and find size A
center = zeros(size(handles.updatedCraw,1),2);
for i = 1:size(handles.updatedCraw,1)
    % COM
    [tmp_r,tmp_c] = find(squeeze(A_full(i,:,:))); % get all rows and columns
    center(i,:) = [mean(tmp_r) mean(tmp_c)]; % find mean of row and column
    % size A
    pixels(i) = length(find(A_full(i,:,:) ~= 0)); % get number of pixels of A
end


function plot_histo_snr(handles)
% plot histogram of SNR

% histsnr
axes(handles.histsnr);
histogram(handles.SNR, 'FaceColor', handles.color_plots(1,:))


function plot_histo_size(handles)
% plot histogram of size

%histsize
axes(handles.histsize);
h = histogram(handles.pixels_A, 'FaceColor', handles.color_plots(1,:));
xlim([0 (h.BinEdges(end) * 1.15)]) % change x lims
hold(handles.histsize,'on')
line([str2num(get(handles.a_min,'String')) str2num(get(handles.a_min,'String'))], [0 max(h.Values)], 'LineWidth', 1, 'Color', handles.color_plots(2,:))% plot manual A_min
line([str2num(get(handles.a_max,'String')) str2num(get(handles.a_max,'String'))], [0 max(h.Values)], 'LineWidth', 1, 'Color', handles.color_plots(2,:))% plot manual A_max

hold(handles.histsize,'off')


function output = load_suite2p_mat(filename1, filepath1, handles)
% load suite2p Fall.mat output and convert to GUI-compatible results struct
%
% inputs:
%   filename1 = filename ('Fall.mat')
%   filepath1 = path to file
%   handles   = GUI handles (for plot_bad setting)
%
% Suite2P conventions:
%   F, Fneu, spks  [nROI x T]  single precision
%   iscell         [nROI x 2]  col1=is_cell(0/1), col2=classifier prob
%   stat           {nROI x 1}  per-ROI struct with ypix, xpix, lam (0-indexed)
%   ops            struct       Ly, Lx, meanImg, meanImgE, tau, fs, ...
%
% NOTE: Python/numpy arrays come transposed when loaded in MATLAB.
%   ops.meanImg is [Lx x Ly] in MATLAB -> transpose to [Ly x Lx] for display.
%   stat ypix/xpix are 0-indexed -> add 1 for MATLAB.

% load file
s2p = load([filepath1 filename1]);

% dimensions
Ly   = double(s2p.ops.Ly);   % rows (height)
Lx   = double(s2p.ops.Lx);   % cols (width)
nROI = size(s2p.F, 1);
T    = size(s2p.F, 2);

% iscell: col 1 = is_cell (0/1), col 2 = classifier probability
iscell_mat = s2p.iscell;
rois_good  = find(iscell_mat(:,1) == 1)';  % 1-indexed, row vector
rois_bad   = find(iscell_mat(:,1) == 0)';  % 1-indexed, row vector

% C_raw: neuropil-corrected fluorescence [nROI x T]
C_raw_all = double(s2p.F) - 0.7 * double(s2p.Fneu);

% S: deconvolved spikes [nROI x T]
S_all = double(s2p.spks);

% C: spike reconstruction via conv(spks, exp(-t/tau)) [nROI x T]
% tau (s) and fs (Hz) are read from ops
tau    = double(s2p.ops.tau);
fs     = double(s2p.ops.fs);
kernel = exp(-(0:(T-1)) / (tau * fs));  % exponential decay kernel in samples
C_all  = zeros(nROI, T, 'double');
for i = 1:nROI
    tmp = conv(S_all(i,:), kernel, 'full');
    C_all(i,:) = tmp(1:T);
end

% A: sparse spatial footprints [Ly*Lx x nROI]
% stat{i}.ypix/xpix are 0-indexed row/col coords in Python [Ly x Lx] space
% after transposing ops images to MATLAB [Ly x Lx]: row=ypix+1, col=xpix+1
A_all = sparse(Ly*Lx, nROI);
for i = 1:nROI
    ypix = double(s2p.stat{i}.ypix) + 1;  % 1-indexed rows
    xpix = double(s2p.stat{i}.xpix) + 1;  % 1-indexed cols
    lam  = double(s2p.stat{i}.lam);
    % clamp to valid image bounds (safety check for edge ROIs)
    valid   = ypix >= 1 & ypix <= Ly & xpix >= 1 & xpix <= Lx;
    lin_idx = sub2ind([Ly, Lx], ypix(valid), xpix(valid));
    A_all(lin_idx, i) = lam(valid);
end

% background images: ops arrays are [Lx x Ly] in MATLAB (transposed from Python)
% transpose to [Ly x Lx] for correct display orientation
Cn = s2p.ops.meanImg';   % mean image -> Cn
Mn = s2p.ops.meanImgE';  % enhanced mean image -> Mn

% store raw data (all ROIs, for bad ROI support)
output.raw.C_raw     = C_raw_all;
output.raw.C         = C_all;
output.raw.S         = S_all;
output.raw.A         = A_all;
output.raw.rois_good = rois_good;
output.raw.rois_bad  = rois_bad;
output.raw.iscell    = iscell_mat;

% store good or all ROIs depending on plot_bad setting.
% native_index maps each working ROI back to its row in the full Fall.mat
% arrays, so save can rebuild a native Fall.mat (see build_native_suite2p).
if handles.plot_bad == 0    % only good ROIs (iscell == 1)
    output.C_raw = C_raw_all(rois_good, :);
    output.C     = C_all(rois_good, :);
    output.S     = S_all(rois_good, :);
    output.A     = A_all(:, rois_good);
    output.native_index = rois_good;
elseif handles.plot_bad == 1  % all ROIs; bad ROIs go to delete list
    output.C_raw    = C_raw_all;
    output.C        = C_all;
    output.S        = S_all;
    output.A        = A_all;
    output.rois_bad = rois_bad;
    output.native_index = 1:nROI;
end

% retain the full native Fall.mat data so save can rebuild a native file
% (only A/C/C_raw/S are used for display; F/Fneu/spks/stat/iscell are what
% Suite2P actually reads back)
output.native.F      = s2p.F;
output.native.Fneu   = s2p.Fneu;
output.native.spks   = s2p.spks;
output.native.stat   = s2p.stat;
output.native.iscell = s2p.iscell;
output.native.ops    = s2p.ops;
% optional second-channel fields (present only for 2-channel recordings)
if isfield(s2p, 'redcell'),    output.native.redcell    = s2p.redcell;    end
if isfield(s2p, 'F_chan2'),    output.native.F_chan2    = s2p.F_chan2;    end
if isfield(s2p, 'Fneu_chan2'), output.native.Fneu_chan2 = s2p.Fneu_chan2; end

% background images
output.Cn = Cn;
output.Mn = Mn;

% settings: store all suite2p parameters
output.settings.pipeline = 'suite2p';
output.settings.d1       = Ly;       % rows (used by get_shape_size_A)
output.settings.d2       = Lx;       % cols (used by get_shape_size_A)
output.settings.fs       = fs;       % sampling rate (Hz)
output.settings.tau      = tau;      % calcium decay time constant (s)
output.settings.ops      = s2p.ops;  % full suite2p ops struct

function update_button_states(handles)
% make delete and merge buttons available when there are ROIs in the
% respective lists
has_del   = ~isempty(handles.delcells);
has_merge = ~isempty(handles.mergecells);
if has_del && ~has_merge
    set(handles.del,   'Enable', 'on');
    set(handles.merge, 'Enable', 'off');
elseif has_merge && ~has_del
    set(handles.del,   'Enable', 'off');
    set(handles.merge, 'Enable', 'on');
else  % both empty, or both non-empty
    set(handles.del,   'Enable', 'off');
    set(handles.merge, 'Enable', 'off');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NATIVE OUTPUT (SAVE)
% These helpers rebuild a file in the SAME format that was loaded, using
% the retained native data and handles.roi_orig (output ROI -> the source
% ROI index/indices behind it). Deleted ROIs are physically gone; merged
% ROIs average their temporal signals and union their footprints; per-ROI
% quantities that cannot be meaningfully combined are set to NaN for
% merged ROIs only (see PRISM.md for the exact per-format list).


function build_native_suite2p(handles, PRISM, file_str)
% rebuild a native Suite2P Fall.mat with only the surviving/merged ROIs.
nat      = handles.rawdata1.results.native;   % full native Fall.mat data
roi_orig = handles.roi_orig;                  % output ROI -> source row(s)
nOut     = numel(roi_orig);
T        = size(nat.F, 2);

F      = zeros(nOut, T, 'like', nat.F);
Fneu   = zeros(nOut, T, 'like', nat.Fneu);
spks   = zeros(nOut, T, 'like', nat.spks);
iscell = zeros(nOut, size(nat.iscell, 2));
stat   = cell(1, nOut);

% redcell/F_chan2/Fneu_chan2 are top-level Fall.mat keys whenever Suite2P
% was run with 2-channel support, but are [0x0] empty placeholders on a
% session with no real second channel / no red-cell pass (as opposed to
% simply being absent). Always carry the key through when Suite2P wrote
% it at all, so the output keeps the same schema as the input: slice
% per-ROI when there is real data to slice, otherwise pass the empty
% placeholder through unchanged (indexing into it would error).
has_red   = isfield(nat, 'redcell');
has_chan2 = isfield(nat, 'F_chan2') && isfield(nat, 'Fneu_chan2');
red_empty   = has_red   && isempty(nat.redcell);
chan2_empty = has_chan2 && (isempty(nat.F_chan2) || isempty(nat.Fneu_chan2));

if has_red && ~red_empty,     redcell    = zeros(nOut, size(nat.redcell, 2)); end
if has_chan2 && ~chan2_empty
    F_chan2    = zeros(nOut, T, 'like', nat.F_chan2);
    Fneu_chan2 = zeros(nOut, T, 'like', nat.Fneu_chan2);
end

for i = 1:nOut
    src = roi_orig{i};
    if isscalar(src)                     % untouched ROI: copy verbatim
        F(i,:)      = nat.F(src,:);
        Fneu(i,:)   = nat.Fneu(src,:);
        spks(i,:)   = nat.spks(src,:);
        iscell(i,:) = [1 nat.iscell(src, 2:end)];
        stat{i}     = nat.stat{src};
        if has_red && ~red_empty,     redcell(i,:) = nat.redcell(src,:); end
        if has_chan2 && ~chan2_empty
            F_chan2(i,:)    = nat.F_chan2(src,:);
            Fneu_chan2(i,:) = nat.Fneu_chan2(src,:);
        end
    else                                 % merged ROI: combine
        F(i,:)      = mean(nat.F(src,:), 1);
        Fneu(i,:)   = mean(nat.Fneu(src,:), 1);
        spks(i,:)   = mean(nat.spks(src,:), 1);
        iscell(i,:) = [1 nat.iscell(src(1), 2:end)]; % cell; keep first's prob
        stat{i}     = combine_stat_suite2p(nat.stat(src));
        if has_red && ~red_empty,     redcell(i,:) = nat.redcell(src(1),:); end
        if has_chan2 && ~chan2_empty
            F_chan2(i,:)    = mean(nat.F_chan2(src,:), 1);
            Fneu_chan2(i,:) = mean(nat.Fneu_chan2(src,:), 1);
        end
    end
end

% assemble as top-level variables (what Suite2P reads back), + PRISM
out = struct();
out.F = F; out.Fneu = Fneu; out.spks = spks;
out.iscell = iscell; out.stat = stat; out.ops = nat.ops;
if has_red
    if red_empty, out.redcell = nat.redcell; else, out.redcell = redcell; end
end
if has_chan2
    if chan2_empty
        out.F_chan2 = nat.F_chan2; out.Fneu_chan2 = nat.Fneu_chan2;
    else
        out.F_chan2 = F_chan2; out.Fneu_chan2 = Fneu_chan2;
    end
end
out.PRISM = PRISM;
save(file_str, '-struct', 'out', '-v7.3');


function s = combine_stat_suite2p(stat_cells)
% combine several Suite2P stat structs: union the pixel lists (summing lam
% on overlap), recompute med/npix; geometry that cannot be unioned -> NaN.
ypix = []; xpix = []; lam = [];
for k = 1:numel(stat_cells)
    ypix = [ypix; double(stat_cells{k}.ypix(:))];
    xpix = [xpix; double(stat_cells{k}.xpix(:))];
    lam  = [lam;  double(stat_cells{k}.lam(:))];
end
[u, ~, ic] = unique([ypix xpix], 'rows');   % merge duplicate pixels
lam_sum = accumarray(ic, lam);
s = stat_cells{1};                           % inherit the first ROI's stat
s.ypix = u(:,1)';                            % then overwrite the pixel list
s.xpix = u(:,2)';
s.lam  = lam_sum';
s.npix = numel(lam_sum);
s.med  = [median(u(:,1)) median(u(:,2))];    % [y x], as suite2p
% all other geometry fields (compact, solidity, radius, ...) are kept from
% the first source ROI unchanged (see PRISM.md)


function build_native_cnmfe(handles, PRISM, file_str)
% rebuild a native CNMF-E .mat. The working arrays already ARE the native
% per-ROI fields (A/C/C_raw/S) in output order, so we take the original
% results struct and swap them in. options/P and everything else pass
% through unchanged - P.sn_neuron/kernel_pars are deliberately NOT
% re-indexed (they are already not 1:1 with ROIs in source; see PRISM.md).
results = handles.rawdata1.results;
results.C_raw = handles.updatedCraw;
results.C     = handles.updatedC;
results.S     = handles.updatedS;
results.A     = handles.updatedA;
% residuals (YrA-style), when a source genuinely has it, IS 1:1 with the
% ROI set, so carry the delete/merge-tracked version through - but only
% when the source actually had one (handles.updatedresiduals is [] from
% init otherwise, and assigning it would add a field the native format
% never had, e.g. plain CNMF-E .mat).
if ~isempty(handles.updatedresiduals)
    results.residuals = handles.updatedresiduals;
end
% SNR_cnmf, when present, is an initialization-era array computed over ALL
% candidate components CNMF considered (including ones already rejected
% before PRISM ever saw the file) - NOT 1:1 with the current ROI set, the
% same situation PRISM.md documents for CNMF-E's P.sn_neuron/kernel_pars.
% Re-indexing it with ROI delete/merge indices (as an earlier version did
% via handles.updatedSNRcnmf) silently scrambles it, so it is deliberately
% left untouched here: `results` above already carries the source's
% original SNR_cnmf through verbatim, or omits it entirely if the source
% never had one.
% Cn: on a raw legacy CNMF-E .mat, LoadFile_Callback transposes Cn
% in-place for correct GUI display (old MATLAB CNMF-E stores it
% transposed relative to what the A-matrix pixel indexing expects).
% `results` above is that same display-oriented struct, so undo the
% transpose here - otherwise the saved file's Cn comes out rotated
% relative to the ORIGINAL file (see PRISM.md/GitHub issue: 240x376 saved
% as 376x240).
if isfield(handles, 'cn_display_transposed') && handles.cn_display_transposed && isfield(results, 'Cn')
    results.Cn = results.Cn';
end
% strip PRISM-internal/legacy fields, then attach the provenance record
for f = {'native','native_index','GUI','SNR_gui','settings'}
    if isfield(results, f{1}), results = rmfield(results, f{1}); end
end
results.PRISM = PRISM;
save(file_str, 'results', '-v7.3');


function patch_hdf5(handles, PRISM, file_str)
% rebuild a native CaImAn/CNMF .hdf5 by copying the original file and
% patching only the per-ROI datasets under /estimates to the surviving
% (possibly merged) ROI set. Everything non-per-ROI (dims, sn, b, f,
% background, /params) is preserved byte-for-byte.
%
% Structured in phases so the file is opened for low-level writing only
% ONCE: (1) read every original dataset and compute its replacement in
% memory, (2) delete all target datasets in a single H5F session, (3)
% recreate them with the high-level API. Resizing a dataset needs a
% delete+recreate, and interleaving many low-level opens with high-level
% h5read/h5create can deadlock on Windows file locking - doing all the
% low-level deletes in one session avoids that.
src      = handles.source_file;
roi_orig = handles.roi_orig;
nOut     = numel(roi_orig);
setenv('HDF5_USE_FILE_LOCKING','FALSE');
copyfile(src, file_str);

% authoritative component count / pixel count from the sparse footprint
shp = double(h5read(file_str, '/estimates/A/shape'));
pix = shp(1);
M   = shp(2);

% temporal datasets that are averaged on merge; everything else per-ROI is
% NaN'd on merge (floats) or kept-first (integers).
avg_set  = {'C','S','YrA','F_dff','R'};
skip_set = {'dims','sn','b','f'};    % never per-ROI even if a dim == M

% ---- phase 1: read originals + compute replacements (no writes yet) ----
dels   = {};                               % dataset paths to delete
wpath  = {};  wdata = {};                  % non-empty datasets to (re)create
info = h5info(file_str, '/estimates');
for d = 1:numel(info.Datasets)
    name = info.Datasets(d).Name;
    if any(strcmp(name, skip_set)), continue; end
    path = ['/estimates/' name];
    if strcmp(name, 'idx_components')      % all survivors are "good"
        v = h5read(file_str, path);
        dels{end+1} = path; wpath{end+1} = path; wdata{end+1} = cast(0:(nOut-1), class(v)); %#ok<AGROW>
        continue
    elseif strcmp(name, 'idx_components_bad')
        dels{end+1} = path;  continue      % delete, leave absent %#ok<AGROW>
    end
    sz = info.Datasets(d).Dataspace.Size;
    a  = find(sz == M, 1);                 % ROI axis
    if isempty(a), continue; end           % not a per-ROI dataset
    v = h5read(file_str, path);
    dels{end+1}  = path; %#ok<AGROW>
    wpath{end+1} = path; %#ok<AGROW>
    wdata{end+1} = patch_axis(v, a, roi_orig, any(strcmp(name, avg_set))); %#ok<AGROW>
end

% sparse footprint A (CSC triplet) - compute new arrays in memory
[Ad, Ai, Ap, Ash] = build_new_A(file_str, roi_orig, pix, M);
Anames = {'data','indices','indptr','shape'};
Avals  = {Ad, Ai, Ap, Ash};
for k = 1:4
    dels{end+1}  = ['/estimates/A/' Anames{k}]; %#ok<AGROW>
    wpath{end+1} = ['/estimates/A/' Anames{k}]; %#ok<AGROW>
    wdata{end+1} = Avals{k};                     %#ok<AGROW>
end

% PRISM provenance datasets
wpath{end+1} = '/PRISM/snr';       wdata{end+1} = double(PRISM.snr(:)');   %#ok<AGROW>
wpath{end+1} = '/PRISM/n_out';     wdata{end+1} = double(PRISM.n_out);     %#ok<AGROW>
wpath{end+1} = '/PRISM/n_merged';  wdata{end+1} = double(PRISM.n_merged);  %#ok<AGROW>
wpath{end+1} = '/PRISM/n_removed'; wdata{end+1} = double(PRISM.n_removed); %#ok<AGROW>
if ~isempty(PRISM.merged_idx)
    wpath{end+1} = '/PRISM/merged_idx'; wdata{end+1} = double(PRISM.merged_idx(:)')-1; %#ok<AGROW>
end

% ---- phase 2: delete every target dataset in ONE low-level session ----
fid = H5F.open(file_str, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
for k = 1:numel(dels)
    try, H5L.delete(fid, dels{k}, 'H5P_DEFAULT'); catch, end
end
H5F.flush(fid, 'H5F_SCOPE_GLOBAL');
H5F.close(fid);

% ---- phase 3: recreate datasets with the high-level API ----
for k = 1:numel(wpath)
    data = wdata{k};
    sz = size(data);
    if isrow(data) || iscolumn(data), sz = numel(data); end
    h5create(file_str, wpath{k}, sz, 'Datatype', class(data));
    h5write(file_str, wpath{k}, data);
end

% ---- phase 4: PRISM group attributes ----
h5writeatt(file_str, '/PRISM', 'used', int8(1));
h5writeatt(file_str, '/PRISM', 'version', PRISM.version);
h5writeatt(file_str, '/PRISM', 'date', PRISM.date);
h5writeatt(file_str, '/PRISM', 'source_pipeline', PRISM.source_pipeline);


function nv = patch_axis(val, a, roi_orig, do_avg)
% shrink/combine a per-ROI array along axis a (1 or 2) per roi_orig.
% Merged ROIs: temporal datasets are averaged; every other per-ROI field
% KEEPS THE FIRST source ROI's value (the merged ROI lives at that slot).
nOut = numel(roi_orig);
if a == 1
    nv = zeros(nOut, size(val,2), 'like', val);
    for i = 1:nOut
        src = roi_orig{i};
        if isscalar(src),   nv(i,:) = val(src,:);
        elseif do_avg,      nv(i,:) = mean(val(src,:), 1);
        else,               nv(i,:) = val(src(1),:);   % keep first source
        end
    end
else % a == 2
    nv = zeros(size(val,1), nOut, 'like', val);
    for i = 1:nOut
        src = roi_orig{i};
        if isscalar(src),   nv(:,i) = val(:,src);
        elseif do_avg,      nv(:,i) = mean(val(:,src), 2);
        else,               nv(:,i) = val(:,src(1));    % keep first source
        end
    end
end


function [data_out, idx_out, ptr_out, shape_out] = build_new_A(file_str, roi_orig, pix, M)
% compute the cleaned /estimates/A (scipy CSC triplet) for the cleaned ROI
% set, WITHOUT writing - the caller writes it in the batched phase.
d    = h5read(file_str, '/estimates/A/data');
ridx = double(h5read(file_str, '/estimates/A/indices')) + 1;  % 1-based rows
cptr = double(h5read(file_str, '/estimates/A/indptr'))  + 1;  % 1-based ptrs
cls_data = class(d);
cls_idx  = class(h5read(file_str, '/estimates/A/indices'));
cls_ptr  = class(h5read(file_str, '/estimates/A/indptr'));
cls_shp  = class(h5read(file_str, '/estimates/A/shape'));

% reconstruct original sparse A [pix x M]
rows = []; cols = []; vals = [];
for c = 1:M
    s = cptr(c); e = cptr(c+1) - 1;
    if e >= s
        rows = [rows; ridx(s:e)];
        cols = [cols; c*ones(e-s+1,1)];
        vals = [vals; double(d(s:e))];
    end
end
Aorig = sparse(rows, cols, vals, pix, M);

% build cleaned A [pix x nOut]: sum footprints for merged, copy singletons
nOut = numel(roi_orig);
Anew = sparse(pix, nOut);
for i = 1:nOut
    src = roi_orig{i};
    if isscalar(src), Anew(:,i) = Aorig(:,src);
    else,             Anew(:,i) = sum(Aorig(:,src), 2);
    end
end

% MATLAB sparse is CSC; find() returns column-major order = CSC order
[ir, jc, vv] = find(Anew);
counts  = accumarray(jc, 1, [nOut 1]);
indptr  = [0; cumsum(counts)];          % 0-based, length nOut+1
indices = ir - 1;                        % 0-based row indices

data_out  = cast(vv,             cls_data);
idx_out   = cast(indices,        cls_idx);
ptr_out   = cast(indptr,         cls_ptr);
shape_out = cast([pix; nOut],    cls_shp);
