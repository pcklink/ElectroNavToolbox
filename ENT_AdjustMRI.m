function ImParams = ENT_AdjustMRI(Vol)

%============================= ENT_AdjustMRI ==============================
% This function opens a GUI window for adjusting the appearance of the input
% MRI volume. 
%
%
% ELECTRONAV TOOLBOX
% Developed by Aidan Murphy, � Copyleft 2015, GNU General Public License
%==========================================================================

global ImParams

if nargin == 0
    [file, path] = uigetfile('*.nii', 'Select an MRI volume to adjust');
    VolumeFile = fullfile(path, file);
    nii = load_nii(VolumeFile);
    Vol = nii.img;
end

%====================== OPEN GUI FIGURE
Fig.Rect = [0 0 800, 800];                                                      % Set figure winow to fullscreen
Fig.FontSize = 14;                                                              % Set defualt font size
Fig.Background = repmat(0.75,[1,3]);                                            % Set figure background color  
Fig.InputBackground = repmat(0.85,[1,3]);                                       % Set input box background color
Fig.AxesBkgColor = repmat(0.75,[1,3]);                                          % Set axes background color
Fig.Handle = figure('Name',sprintf('ElectroNav%c - Adjust MRI',char(169)),... 	% Open a figure window with specified title
                    'Color',Fig.Background,...                                  % Set the figure window background color
                    'Renderer','OpenGL',...                                     % Use OpenGL renderer
                    'Position', Fig.Rect,...                                    % position figure window to fit fullscreen
                    'visible','off',...                                         % Figure remains invisible until complete
                    'menu','none','toolbar','none',...                          % Remove toolbar etc
                    'NumberTitle','off',...                                     % Remove figure number from title
                    'IntegerHandle','off');                                     % Don't use integer handles

                
%====================== SET DEFAULTS
ImParams.Thresh     = [min(Vol(:)), max(Vol(:))];
ImParams.Colormap   = gray;
ImParams.Resolution = nii.hdr.dime.pixdim(2:4);

 
%====================== CREATE GUI BUTTONS                
Fig.MRI.LabelStrings = {'MR volume','Slice axis','Position (mm)','Threshold'};

Fig.MRI.InputType = {'Pushbutton','popupmenu','slider','slider','Jslider'};
Fig.MRI.InputStrings = {{'Select volume'}, {'Sagittal','Coronal','Axial'}};
Fig.MRI.InputValue = {0, MRI.SelectedAxis, 0, MRI.SliceAlpha, 0, 1};
Ypos = (0:-30:(-30*(numel(Fig.MRI.LabelStrings)+1))) + BoxPos(5,4)-50;
for i = 1:numel(Fig.MRI.LabelStrings)
    Fig.Handles.MRILabel(i) = uicontrol('Style','text', 'string', Fig.MRI.LabelStrings{i},'HorizontalAlignment','Left', 'pos', [10, Ypos(i), 80, 25],'parent',Fig.Handle);
    if i <= 2
        Fig.Handles.MRIInput(i) = uicontrol('Style',Fig.MRI.InputType{i},'String',Fig.MRI.InputStrings{i},'value',Fig.MRI.InputValue{i}, 'pos',[100, Ypos(i), 150, 25],'parent',Fig.Handle,'Callback',{@MRIView,i});
    else
        if strcmp(Fig.MRI.InputType{i},'Jslider')
            Fig.JavaHandles.MRIInput = javax.swing.JSlider;
            [class,Fig.JavaHandles.jSlider_thresh]  = javacomponent(Fig.JavaHandles.MRIInput,[100, Ypos(i), 150, 25], 'parent', Fig.Handles.UIpannel(3));%, 'StateChangedCallback', {@MRIView, Fig.Handles.UIpannel(3)});
            
        else
            Fig.Handles.MRIInput(i) = uicontrol('Style',Fig.MRI.InputType{i},'value',Fig.MRI.InputValue{i}, 'pos',[100, Ypos(i), 150, 25],'parent',Fig.Handle,'Callback',{@MRIView,i});
        end
    end
end
set(Fig.Handles.MRIInput(4),'min',0,'max',1,'SliderStep',[0.05 0.05]);
set(Fig.Handles.MRIInput([2,3,4]), 'enable', 'off');
set(Fig.Handles.MRIInput(5),'min',0,'max',1,'SliderStep',[0.01 0.01],'backgroundcolor',[0.4, 0.4, 0.4]);


%=================== PLOT DATA
Fig.Handles.MRIint = axes('parent',Fig.Handle, 'units','pixels','position',[40 40 200 80]);
hist(double(MRI.Nii.img(:)),1000);
xlabel('Voxel intensities');
ylabel('# voxels');



    

uiwait;



end

%========================= GUI MENU CALLBACK ==============================
function MRIView(hObj, Event, Indx)
global ImParams
    switch Indx
        case 1

        case 2

        case 3
            MRI.IntensityRange = [min(double(MRI.Nii.Original(:))), max(double(MRI.Nii.Original(:)))];	% Get range of intensity values in MRI
            Thresh = get(Fig.Handles.MRIint, 'xlim');                                                   % Get current thresholds
            Thresh(Indx-4) = MRI.IntensityRange(1)+get(hObj,'Value')*MRI.IntensityRange(2);             % Update selected threshold
            set(Fig.Handles.MRIint, 'xlim', Thresh);                                                    % Update intensity histogram
            MRI.Nii.img = double(MRI.Nii.Original);                      
            MRI.Nii.img(MRI.Nii.img<Thresh(1)) = Thresh(1);                                             % Apply thresholds
            MRI.Nii.img(MRI.Nii.img>Thresh(2)) = Thresh(2);                                             % Apply thresholds
            MRI.Nii.img = (MRI.Nii.img-Thresh(1))/diff(Thresh);                                         % Normalize intensity range (0-1)
            UpdateSlice;                                                                                % Draw MRI slice

        case 4

    end
end

%========================== UPDATE PLOTS ==================================
function UpdateSlice




end