function h = ElectroNavGUI(SubjectID)

%============================== ElectroNavGUI.m ============================== 
% This function plots several 3D visualizations of electrode position 
% relative to the specified grid hole, guide tube, and estimated target depth. 
% Data can be saved and loaded, and various options are provided for
% visualization through the GUI.
%
% INPUTS:
%       ParamsFile:     full filename of .mat file containing default directories
%       Subject ID:     animal name or ID number
%
% MATLAB REQUIREMENTS (INCLUDED):
% 	Graph Theory Toolbox:   http://www.mathworks.com/matlabcentral/fileexchange/5355-toolbox-graph
%   Nifti toolbox:          http://www.mathworks.us/matlabcentral/fileexchange/8797-tools-for-nifti-and-analyze-image
%
% MRI DATA REQUIREMENTS:
%   NeuroMaps:  http://nitrc.org/projects/inia19/
%   McLaren:    http://brainmap.wisc.edu/monkey.html
%   Frey:       http://www.bic.mni.mcgill.ca/ServicesAtlases/Rhesus
%
% REFERENCES:
%   Frey S, Pandya DN, Chakravarty MM, Bailey L, Petrides M, Collins DL 
%       (2011). An MRI based average macaque monkey stereotaxic atlas and 
%       space (MNI monkey space). NeuroImage, 55(4): 1435-1442.
%   McLaren DG, Kosmatka KJ, Oakes TR, Kroenke CD, Kohama SG, Matochik JA,
%       & Johnson SC (2009). A population-average MRI-based atlas collection 
%       of the rhesus macaque. Neuroimage, 45(1): 52-59.
%   Paxinos et al.(2008). 
%
%   Rohlfing et al. (2012). The INIA19 template and NeuroMaps atlas for 
%       primate brain image parcellation and spatial normalization.
%       Frontiers in Neuroinformatics, 
%   Saleem KS & Logothetis NK (2012). Atlas of the Rhesus monkey brain.
%
%
% LICENCE:
%    ElectroNav Toolbox is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version. ElectroNav is distributed in the 
%    hope that it will be useful, but WITHOUT ANY WARRANTY; without even the 
%    implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
%    See the GNU General Public License for more details. You should have received 
%    a copy of the GNU General Public License along with ElectroNav Toolbox. 
%    If not, see <http://www.gnu.org/licenses/>.
%
% REVISIONS:
%   16/08/2013 - Written by APM.
%   23/10/2013 - GUI control and nifti import added
%   24/10/2013 - Option to save and load parameters to .xls file added
%   22/11/2013 - 3D view added
%   26/02/2014 - Updated for imporved view layout
%   03/03/2014 - Default parameters are now loaded from .mat file
%   06/04/2014 - Load transform matrix and apply to electrode
%   29/01/2015 - Update figure handlingfor MATLAB R2014b
%     ___  ______  __   __
%    /   ||  __  \|  \ |  \    APM SUBFUNCTIONS
%   / /| || |__/ /|   \|   \   Aidan P. Murphy - murphyap@mail.nih.gov
%  / __  ||  ___/ | |\   |\ \  Section of Cognitive Neurophysiology and Imaging
% /_/  |_||_|     |_| \__| \_\ Laboratory of Neuropsychology, NIMH
%==========================================================================

% persistent Fig
global Electrode Target Fig Grid Session Button Surface Brain Contact Defaults Layer

set(0,'DefaultLineLineSmoothing','on');
set(0,'DefaultPatchLineSmoothing','on');
[RootDir, mfile] = fileparts(mfilename('fullpath'));
addpath(genpath(RootDir));
Session.RootDir = RootDir;


%================== LOAD SUBJECT PARAMETERS & DIRECTORIES =================
[t, CompName] = system('hostname');
DefaultFilename = sprintf('ParamsFile_%s.mat', CompName(1:end-1));
if exist(DefaultFilename)
    DefaultParametersFile = DefaultFilename;
else
    DefaultParametersFile = [];
end
if exist('SubjectID','var')
    Defaults = EN_Initialize(DefaultParametersFile, SubjectID);
else
    Defaults = EN_Initialize(DefaultParametersFile);
end
Defaults.MRIRootDir = [];
Defaults.DateFormats = {'yyyymmdd','ddmmyy'};   
Session.Date = date;
Session.Subject = Defaults.SubjectID;
Session.ElectrodeID = 'PLX24';                  % Default electrode ID
Session.GuideLength = 27;                       % Default guidetube length (mm)
Target = [0,0];


%=============== CALCULATE ROTATION MATRICES
if exist(Defaults.Xform,'file')
    if strcmp(Defaults.Xform(end-2:end),'mat')
        load(Defaults.Xform);
        Brain.Xform = T;
        Brain.ChamberOrigin =  T*[0 0 0 1]';
    elseif strcmp(Defaults.Xform(end-4:end),'xform')
        fileID = fopen(Defaults.Xform);                                     % Open Xform file
        Defaults.Xform = cell2mat(textscan(fileID,'%f %f %f %f\n'));       	% Read Xform to matrix
        Defaults.InverseXform = inv(Defaults.Xform);                       	% Calculate inverse transform matrix
        fclose(fileID);                                                 	% Close xform file
        Brain.Xform = Defaults.Xform;                                       
        Brain.ChamberOrigin = Brain.Xform*[0 0 0 1]';                       % Get grid origin (translation)
    end
end
    

%=================== SET GRID AND ELECTRODE SPECIFICATIONS ================
Grid = GetGridParams(Defaults.GridID);                   	% Get grid parameters based on grid ID
Grid.GuideLength = Session.GuideLength;                     % Set guide tube length
Electrode.QualityColorMap = [0 0 0; 1 0 0; 1 0.5 0; 1 1 0; 0 1 0];
Electrode.ID = Session.ElectrodeID;                         % 
Electrode = GetElectrodeParams(Electrode);                  % Get electrode parameters based on electrode ID
Electrode.AllTypes = sortrows(GetElectrodeParams');         % Get list of all electrode types             
Electrode.CurrentDepth = 0;                               	% Set default start depth (mm)


%=============== LOAD RECORDING HISTORY FROM SPREADSHEET
if exist(Defaults.HistoryFile, 'file') ==2                          % If recording history file was found...
    [a,b,HistoryFormat] = fileparts(Defaults.HistoryFile);      
    if strcmpi(HistoryFormat, '.xls')                               % If file format was Excel...
     	if exist('readtable.m','file')                              % For MATLAB R2014a and later...
            T = readtable(Defaults.HistoryFile);
            T.Date = datetime(T.Date,'ConvertFrom','excel');
            Electrode.DateStrings = char(datetime(T.Date,'format','dd-MMM-yyyy'));   
        else                                                        % MATLAB R2013b and earlier...    
            [num,txt,raw] =  xlsread(Defaults.HistoryFile,1,'');  	% Read data from Excel file
            Headers = txt{1,:};                                  	% Skip row containing column titles
            num(1,:) = [];                                       	% Remove nans
            Dates = num(:,1)+datenum('30-Dec-1899');             	% Convert Excel dates to Matlab dates
            Electrode.DateStrings = datestr(Dates);                     
        end
    elseif strcmpi(HistoryFormat, '.csv')                           % If file format was csv...
        fid = fopen(Defaults.HistoryFile,'rt');
        Headers = textscan(fid, '%s%s%s%s%s%s%s\n', 1, 'delimiter', ',');
        data = textscan(fid, '%f %d %d %f %f %f %s','headerlines',1,'delimiter',',');
        fclose(fid);
        Dates = data{1};   
        Electrode.DateStrings = datestr(Dates); 
    end           
else
    Electrode.DateStrings = [];
end
Electrode.DateStrings(end+1,:) = date;                          % Add todays date to end of list
Electrode.CurrentDate = size(Electrode.DateStrings,1);          % Default to todays date   


%============== SET DEFAULT 3D SURFACE PARAMS
Brain.Specular = 0.2;
Brain.Ambient = 0.2;
Brain.Diffuse = 0.6;
Brain.Alpha = 0.5;
Brain.RGB = [0.7 0.6 0.6];
Brain.DefaultView = [-120 20];                                  
Brain.SurfaceColors = [1 0 0;0 1 0;0 0 1;1 1 0;1 0 1;0 1 1];
Brain.PlanesAlpha = 0.4;                                    
Brain.PlanesRGB = [1 0 0];                                  
Brain.PlanesOn = 1;                                         


%===================== LOAD GRID SCAN AND ATLAS VOLUMES ===================
Layer.Filenames = {Defaults.MRI, Defaults.Atlas};
Layer.Names = {'Native','Atlas'};       	
Layer.Colormap = [];                                        
Layer.ColormapOrder = {gray; jet; hot; cool};               % Different colormap for each layer
Layer.CurrentSliceView = 1;
Layer.CurrentStructure = 1;
Layer.Opacity = [1, 0.5,0.5,1];                           	% Set default alpha transparency for each layer 
Layer.Colors = [0.5,0.5,0.5; 1 0 0; 0 1 0; 0 0 1];          % Set default colors for each layer (RGB)
Layer.Smoothing = [0, 0.5, 1];                              % Set default Gaussian kernel for each layer (mm)
Layer.On = [1 1 1 1];                                       % Set default layer visibility 
Layer.hsize = [5 5];                                        % Size of Gaussian smoothing kernel
Layer.sigma = zeros(1,numel(Layer.Names));                	% default sd of Gaussian (mm)
Layer.SigmaMax = 5;                                         % maximum sd (mm)
Layer.SigmaMin = 0;                                         % minimum sd (mm)
Layer.IntensityRange = [0 255]; 
Layer.ZoomOn = 0;                                           % zoom defaults to off
Layer.ZoomLevel = 15;                                   	% space in mm to include around contacts when zoomed in

for n = 1:numel(Layer.Filenames)
    nii = load_nii(Layer.Filenames{n});
    if n == 1
        nii.img(nii.img>10000) = 10000;
    end
    Layer.MRI(n).img = double(nii.img);                                             % Save image volume
    Layer.MRI(n).VoxelDim = nii.hdr.dime.pixdim(2:4);                               % Get voxel size (mm)
    Layer.MRI(n).DimVox = size(nii.img);                                            % Get full volume dimensions (voxels)
    Layer.MRI(n).DimMM = Layer.MRI(n).DimVox.*Layer.MRI(n).VoxelDim;                % Convert volume dim to mm
    Layer.MRI(n).OriginVox = nii.hdr.hist.originator(1:3);                          % Get origin coordinates (voxels)
    Layer.MRI(n).OriginMM = Layer.MRI(n).OriginVox.*Layer.MRI(n).VoxelDim;        	% Convert origin to mm
    
    if nii.hdr.hist.sform_code > 0                                                  % Use S-form?
        Layer.MRI(n).Sform = [nii.hdr.hist.srow_x; nii.hdr.hist.srow_y; nii.hdr.hist.srow_z];
        Layer.MRI(n).Sform(4,:) = [0 0 0 1];
    end
    if nii.hdr.hist.qform_code > 0                                                  % Use Q-form?
        Layer.MRI(n).Rmat = Quarternion2Rotation(nii.hdr.hist.quatern_b, nii.hdr.hist.quatern_c, nii.hdr.hist.quatern_d);
        Layer.MRI(n).Tmat = [nii.hdr.hist.qoffset_x, nii.hdr.hist.qoffset_y, nii.hdr.hist.qoffset_z];
    end
    
  	Layer.MRI(n).LowerBoundsMM = [nii.hdr.hist.srow_x(4), nii.hdr.hist.srow_y(4), nii.hdr.hist.srow_z(4)];
    Layer.MRI(n).UpperBoundsMM = Layer.MRI(n).DimMM-abs(Layer.MRI(n).LowerBoundsMM);
    Layer.MRI(n).BoundsSagMM = [Layer.MRI(n).LowerBoundsMM(1), Layer.MRI(n).UpperBoundsMM(1)];   % Get bounds in sagital plane (mm)
    Layer.MRI(n).BoundsCorMM = [Layer.MRI(n).LowerBoundsMM(2), Layer.MRI(n).UpperBoundsMM(2)];   % Get bounds in coronal plane (mm)
    Layer.MRI(n).BoundsAxMM = [Layer.MRI(n).LowerBoundsMM(3), Layer.MRI(n).UpperBoundsMM(3)];    % Get bounds in axial plane (mm)
    
   
    Layer.Colormap = [Layer.Colormap; Layer.ColormapOrder{n}]; 
    close gcf;
    if n > 1
        Layer.MRI(n).AlphaMaskVolume = zeros(size(nii.img));                        % Create alpha mask volume equal in size to atlas volume
        Layer.MRI(n).AlphaMaskVolume(nii.img > 0) = 1;                              % For all atlas voxels > 0, mask volume voxels = 1
        Layer.MRI(n).img(nii.img>1000) = Layer.MRI(n).img(nii.img>1000)-1000;       % Make both hemispheres of atlas volume equal indices
    end
  	MRImin = min(min(min(Layer.MRI(n).img)));                                       % Scale voxel intensities to range 0-1  
    MRImax = max(max(max(Layer.MRI(n).img)));
    Layer.MRI(n).img = ((Layer.MRI(n).img-MRImin)/(MRImax-MRImin))+n-1;
    if n == 1
        Layer.MRI(n).img = Layer.MRI(n).img-0.0001;
    end
end



%==================== CHECK MRI AND ATLAS VOLUMES
if Layer.MRI(2).VoxelDim~=Layer.MRI(1).VoxelDim                                           	% If voxel sizes differ between volumes...
    fprintf('Atlas voxel dimensions do not match MRI voxel dimensions!\n');
    Layer.MRI(2).Scaling = Layer.MRI(2).VoxelDim./Layer.MRI(1).VoxelDim;                  	% Atlas must be scaled by this factor to match MRI
    Layer.MRI(2).PostScalingDim = Layer.MRI(2).DimVox.*Layer.MRI(2).Scaling;               	% Get dimmensions (voxels) of scaled atlas volume
    if Layer.MRI(2).PostScalingDim ~= Layer.MRI(1).DimVox                                  	% If scaled atlas dimensions don't match MRI...
        fprintf('Scaled atlas volume dimensions do not match MRI volume dimensions!\n');
    end

end


%========================== 3D surface settings ==============================
Surface.Atlas = 'NeuroMaps';
switch Surface.Atlas
    case 'Paxinos'
        Surface.VTKfile = 'Niftii/Frey/Paxinos_surface.vtk';
     	Surface.Xlim = [-32 32];
        Surface.Ylim = [-60 30];
        Surface.Zlim = [-20 40];
    case 'NeuroMaps'
        Surface.VTKfile = fullfile(Defaults.VTKdir,'Cortical_surface.vtk');
        Surface.StructFolder = Defaults.VTKdir;
       	Surface.Xlim = [-32 32];
        Surface.Ylim = [-50 30];
        Surface.Zlim = [-25 45];
    case 'Saleem-Logothetis'
        Surface.VTKfile = 'Niftii/McLaren/McLaren_surface.vtk';
        Surface.Xlim = [-32 32];
        Surface.Ylim = [-30 60];
        Surface.Zlim = [-10 50];
end 



%% =========================== FIGURE SETTINGS ==============================
Fig.Background = [0.75 0.75 0.75];                       	% Set figure window background color
Fig.AxesBkgColor = [0.75 0.75 0.75];                       	% Set axes background color 
Fig.FontSize = 12;                                          % Set default font size for axis labels etc
Fig.UIFontsize = 12;                                        
Fig.PlotSpacing = 50;                                       % Set spacing between plots (pixels)
Fig.CoordinatesInMM = 1;                                    % Set units for displaying coordinates
scnsize = get(0,'ScreenSize');                              % Get screen resolution
Fig.Rect = [0 0 scnsize([3,4])];                            % Specify full screen rectangle
Fig.Handle = figure('Name','ElectroNav',...                 % Open a figure window with specified title
                    'Color',Fig.Background,...              % Set the figure window background color
                    'Renderer','OpenGL',...               	% Use OpenGL renderer
                    'OuterPosition', Fig.Rect,...          	% position figure window to fit fullscreen
                    'Visible','off',...                     % make figure window invisible until fully loaded
                    'NumberTitle','off',...                 % Remove figure number from title
                    'IntegerHandle','off',...               % Don't use integer handles
                    'Menu','none','Toolbar','none');       	% Turn off toolbars to save space
Fig.Rect = get(Fig.Handle, 'Position');                     % Get dimensions of usable figure space
Fig.UIControlDim = [220, 180];                              % Set dimensions of GUI control boxes (pixels)
Fig.Az = 20;                                                % Set azimuth angle (deg) for 3D view
Fig.El = 40;                                                % Set elevation angle (deg) for 3D view
Fig.Position(1,:) = [0.15,0.75,0.25,0.25];                 	% Set axis positions (normalized units)
Fig.Position(2,:) = [0.15,0.4,0.25,0.25];
Fig.Position(3,:) = [0.15,0.05,0.25,0.25];
Fig.Position(4,:) = [0.3,0.1,0.8,0.8];
Fig.Position(5,:) = [0.90,0.05,0.10,0.9];

                
%============================ CREATE MENUS ==============================

%======================= FILE TAB
Fig.FileMenuH{1} = uimenu(Fig.Handle,'Label','File'); 
Fig.FileLabels = {'Load session','Save session','Edit defaults','Load structures','Export figure','View session MRI','Quit'};
Fig.ExportLabels = {'Full window','MRI panel'};
Fig.FileAccelerators = {'L','S','','','E','','Q'};
for n = 1:numel(Fig.FileLabels)
    Fig.FileMenuH{2}(n) = uimenu(Fig.FileMenuH{1},...
                                'Label',Fig.FileLabels{n},...
                                'Callback',{@FileSelect,n,0},...
                                'Accelerator', Fig.FileAccelerators{n},...
                                'Enable','on');
end
set(Fig.FileMenuH{2}(n), 'Separator','on');
for m = 1:numel(Fig.ExportLabels)
    Fig.FileMenuH{3}(m) = uimenu(Fig.FileMenuH{2}(5),...                      % Create sub-options
                               'Label',Fig.ExportLabels{m},...
                               'Callback',{@FileSelect,5,m},...
                               'Enable','on');  
end


%======================= ATLAS TAB
Fig.AtlasMenuH{1} = uimenu(Fig.Handle,'Label','Atlas');
Fig.AtlasLabels{1} = {'3D slice view', '3D surface view','BrainMaps.org','ScalableBrainAtlas.org','PDFs'};
Fig.AtlasLabels{2} = [];
Fig.AtlasLabels{3} = [];
Fig.AtlasLabels{4} = {'Axial','Coronal','Sagittal'};                
Fig.AtlasLabels{5} = {'NeuroMaps','Paxinos','Carret'};              
Fig.AtlasPDFDir = fullfile(RootDir,'Documentation/Atlas PDFs/');                      
PDFFiles = dir(Fig.AtlasPDFDir);                                  	% Get list of PDF files in Atlas PDF folder
PDFFiles = PDFFiles(arrayfun(@(x) x.name(1), PDFFiles) ~= '.');     % Remove '.' prefixed files/ dirs
PDFFilenames = struct2cell(PDFFiles);                               % Convert structure to cell
PDFFilenames(2:end,:) = [];                                         % Remove all fields except for file names
Fig.AtlasLabels{6} = PDFFilenames;                                  % List all PDF files in PDF menu
for m = 1:numel(Fig.AtlasLabels{1})
    Fig.AtlasMenuH{2}(m) = uimenu(Fig.AtlasMenuH{1},'Label',Fig.AtlasLabels{1}{m});
    for n = 1:numel(Fig.AtlasLabels{1+m}) 
        Fig.AtlasMenuH{2+m}(n) = uimenu(Fig.AtlasMenuH{2}(m),...                      % Create sub-options
                                       'Label',Fig.AtlasLabels{1+m}{n},...
                                       'Callback',{@AtlasSelect,m,n},...
                                       'Enable','on');                                          
    end
end

%======================= DATA TAB
Fig.DataMenuH{1} = uimenu(Fig.Handle,'Label','Data');                               % Create data tab on menu bar
Fig.DataLabels{1} = {'Raw','Experimental','Recording history'};                 	% List main data tab options
Fig.DataLabels{2} = {'LFPs','Spike waveforms'};                                     % List sub options for each main option  
Fig.DataLabels{3} = {'RF mapping','Pic tuning','Movie'};
Fig.DataLabels{4} = {'Frequency by hole','Recency by hole'};

for m = 1:numel(Fig.DataLabels{1})                                                     
    Fig.DataMenuH{2}(m) = uimenu(Fig.DataMenuH{1},'Label',Fig.DataLabels{1}{m});  	% Create option
    
    for n = 1:numel(Fig.DataLabels{1+m}) 
        Fig.DataMenuH{2+m}(n) = uimenu(Fig.DataMenuH{2}(m),...                      % Create sub-options
                                       'Label',Fig.DataLabels{1+m}{n},...
                                       'Callback',{@DataSelect,m,n},...
                                       'Enable','on');                                          
    end
end

%======================= HELP TAB
Fig.HelpMenuH{1} = uimenu(Fig.Handle,'Label','Help');
Fig.HelpLabels = {'Documentation','About'};
for n = 1:numel(Fig.HelpLabels)
    Fig.HelpMenuH{2}(n) = uimenu(Fig.HelpMenuH{1},'Label',Fig.HelpLabels{n},'Callback','EN_About','Enable','on');
end

%====================== DISABLE UNAVAILABLE MENU OPTIONS
if exist(Defaults.ExpDir) == 0                                  % If experimental data directory was not found...
    set(Fig.DataMenuH{2}([1,2]),'Enable','off');            	% Disable loading physiology data
end
if exist(Defaults.MRIRootDir) == 0
    set(Fig.FileMenuH{2}(6),'Enable','off');                    % Disable loading post-recording MRI data
end
if exist(Defaults.HistoryFile) == 0                               % If recording history Excel file was not found...
  	set(Fig.FileMenuH{2}(1),'Enable','off');                 	% Disable loading previous session data
    set(Fig.DataMenuH{2}(3),'Enable','off');
end



%% ========================== DRAW 3D VIEWS ===============================
set(0, 'currentfigure', Fig.Handle);
set(Fig.Handle,'units','normalized');
Fig.PlotHandle(1) = axes('units','normalized');                             % Axes 1 displays 2D grid view from above
set(Fig.PlotHandle(1),'position',Fig.Position(1,:));
Grid = Draw2DGrid(Grid,[0 0 0]);

Fig.PlotHandle(2) = axes('position',Fig.Position(2,:));                   	% Axes 2 displays axial whole brain view (3D)
Brain = DrawBrain3D(Brain, Electrode, Grid);
view(0,90);
camlight headlights;
        
Fig.PlotHandle(3) = axes('position',Fig.Position(3,:));                   	% Axes 3 displays coronal whole brain view (3D)
Brain = DrawBrain3D(Brain, Electrode, Grid);
view(0,0);
camlight headlights;

Fig.PlotHandle(4) = axes('position',Fig.Position(4,:));                  	% Axes 4 displays electrode MRI sagittal view
Layer.M = DrawMRI(Target, Electrode);
Electrode.GT = DrawGuidetube(Target, Electrode);   
Electrode = DrawElectrode(Target, Electrode);   

Fig.PlotHandle(5) = axes('position',Fig.Position(5,:));                  	% Axes 5 displays electrode contact selection
Electrode = DrawContacts(Electrode);

set(Fig.PlotHandle, 'fontsize', Fig.FontSize);


%% ======================= INITIALIZE UI CONTROLS =========================
Logo= imread(fullfile('Documentation','ElectroNavLogo1.png'),'BackgroundColor',Fig.Background);
LogoAx = axes('box','off','units','pixels','position', [20, Fig.Rect(4)-150, Fig.UIControlDim(1), 42],'color',Fig.Background);
image(Logo);
axis equal off

Session.BoxPos = [20 Fig.Rect(4)-300 Fig.UIControlDim(1), 120];
Button.BoxPos = [20 Session.BoxPos(2)-170 Fig.UIControlDim(1), 160];
Contact.BoxPos = [20 Button.BoxPos(2)-170 Fig.UIControlDim(1),160];
Layer.BoxPos = [20 Contact.BoxPos(2)-180 Fig.UIControlDim(1),170];
Surface.BoxPos = [20 Layer.BoxPos(2)-10 Fig.UIControlDim, 110];

%=============== SESSION DETAILS
Session.InputDim = [100 20];
Session.Labels = {'Subject ID','Date','Electrode type','# channels'};
Session.Style = {'Text','popup','popup','edit'};
Session.List = {Session.Subject, Electrode.DateStrings, Electrode.AllTypes, 24};
Session.UIhandle = uipanel('Title','Session details','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','pixels','Position',Session.BoxPos);
for i = 1:numel(Session.Labels)
    Pos = numel(Session.Labels)-i;
    Session.LabelPos{i} = [10, 10+Pos*Session.InputDim(2),Session.InputDim];
    Session.LabelHandle(i) = uicontrol( 'Style','Text',...
                                        'String',Session.Labels{i},...
                                        'HorizontalAlignment','Left',...
                                        'pos',Session.LabelPos{i},...
                                        'parent',Session.UIhandle);
    Session.InputHandle(i) = uicontrol( 'Style',Session.Style{i},...
                                        'String',Session.List{i},...
                                        'HorizontalAlignment','Left',...
                                        'pos',[Session.InputDim(1)+10,15+Pos*Session.InputDim(2),100,20],...
                                        'Callback',{@SessionParams,i},...
                                        'parent',Session.UIhandle);
end
set([Session.LabelHandle,Session.InputHandle], 'BackgroundColor',Fig.Background);
set(Session.InputHandle(2),'value', Electrode.CurrentDate);


%=============== ELECTRODE POSITION
Button.InputDim = [100 20];
Button.Labels = {'M-L','A-P','Manual depth','Microdrive depth','Total depth','Guide length'};
Button.CurrentValues = {Target(1),Target(2),0, 0, Electrode.CurrentDepth, Session.GuideLength};
Button.Units = {'holes','holes','mm','mm','mm','mm'};
Button.UIhandle = uipanel('Title','Electrode position','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','pixels','Position',Button.BoxPos);
for i = 1:numel(Button.Labels)
    Pos = numel(Button.Labels)-i;
    Button.LabelPos{i} = [10, 10+Pos*Button.InputDim(2),Button.InputDim];
    Button.LabelHandle(i) = uicontrol(  'Style','Text',...
                                        'String',Button.Labels{i},...
                                        'HorizontalAlignment','Left',...
                                        'pos',Button.LabelPos{i},...
                                        'parent',Button.UIhandle);
    Button.InputHandle(i) = uicontrol(  'Style','edit',...
                                        'String',num2str(Button.CurrentValues{i}),...
                                        'HorizontalAlignment','Left',...
                                        'pos',[Button.InputDim(1)+10,15+Pos*Button.InputDim(2),50,25],...
                                        'parent',Button.UIhandle,...
                                        'Callback',{@ElectrodePos,i});
    Button.UnitsHandle(i) = uicontrol(  'Style','Text',...
                                        'String',Button.Units{i},...
                                        'HorizontalAlignment','Left',...
                                        'pos',[170,10+Pos*Button.InputDim(2),40,20],...
                                        'parent',Button.UIhandle);
end
set([Button.LabelHandle,Button.InputHandle,Button.UnitsHandle], 'BackgroundColor',Fig.Background);

%=============== CONTACT SELECTION
Contact.InputDim = [100 20];
Contact.Labels = {'Contact #',sprintf('Spike quality (1-%d)', size(Electrode.QualityColorMap,1)),'Zoom level (mm)','Zoom to contacts','Go to slice'};
Contact.Input = {num2str(Electrode.CurrentSelected), num2str(Electrode.ContactData(Electrode.CurrentSelected)),num2str(Layer.ZoomLevel)};
Contact.Style = {'Text', 'Text', 'Text','ToggleButton','PushButton'};
Contact.UIhandle = uipanel('Title','Contact selection','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','pixels','Position',Contact.BoxPos);
for i = 1:numel(Contact.Labels)
    Pos = numel(Contact.Labels)-i;
    Contact.LabelPos{i} = [10, 10+Pos*(Contact.InputDim(2)+5),Contact.InputDim];
    if ismember(i, [1,2,3])
        Contact.LabelHandle(i) = uicontrol( 'Style','Text',...
                                            'String',Contact.Labels{i},...
                                            'HorizontalAlignment','Left',...
                                            'pos',Contact.LabelPos{i},...
                                            'parent',Contact.UIhandle);
        Contact.InputHandle(i) = uicontrol( 'Style','Edit',...
                                            'String',Contact.Input{i},...
                                            'HorizontalAlignment','Left',...
                                            'pos',[Contact.LabelPos{i}(1)+Contact.InputDim(1),Contact.LabelPos{i}(2),50,25],...
                                            'parent',Contact.UIhandle,'Callback',{@ContactSelect,i});
    else
        Contact.InputHandle(i) = uicontrol( 'Style',Contact.Style{i},...
                                            'String',Contact.Labels{i},...
                                            'HorizontalAlignment','Left',...
                                            'pos',Contact.LabelPos{i},...
                                            'parent',Contact.UIhandle,...
                                            'Callback',{@ContactSelect,i});
    end
end
set([Contact.LabelHandle, Contact.InputHandle], 'BackgroundColor',Fig.Background);


%================ OVERLAY LAYER SELECTION
Layer.ButtonDim = [100 20];
Layer.UIhandle = uipanel('Title','Layer controls','FontSize', Fig.UIFontsize,'Units','pixels','Position',Layer.BoxPos);
Layer.StructNames = {'Native T1', 'Atlas'};
Layer.LabelStrings = {'Main view','Current structure','Color','Opacity','Smoothing',''};
Layer.InputType = {'popupmenu','popupmenu','PushButton','slider','slider', 'checkbox'};
Layer.InputStrings = {{'Sagittal','Coronal','Axial'}, Layer.StructNames, [], [], [], 'Outline?'};
Layer.InputValue = {Layer.CurrentSliceView, Layer.CurrentStructure, [], Layer.Opacity(Layer.CurrentStructure), Layer.Smoothing(Layer.CurrentStructure), 0};
Layer.ButtonPos = [repmat(10,[numel(Layer.LabelStrings),1]), [0:20:((numel(Layer.LabelStrings)-1)*20)]'+30];
Layer.ButtonPos = Layer.ButtonPos(end:-1:1,:);
for i = 1:numel(Layer.LabelStrings)
    Layer.LabelHandle(i) = uicontrol('Style','text', 'string', Layer.LabelStrings{i},'HorizontalAlignment','Left', 'pos', [Layer.ButtonPos(i,:), Layer.ButtonDim],'parent',Layer.UIhandle);
    Layer.InputHandle(i) = uicontrol('Style',Layer.InputType{i},'String',Layer.InputStrings{i},'value',Layer.InputValue{i}, 'pos',[Layer.ButtonPos(i,:)+[Layer.ButtonDim(1), 0], Layer.ButtonDim],'parent',Layer.UIhandle,'Callback',{@LayerView,i}); 
end
Layer.SliderLabel(1) = uicontrol('Style','Text','String',sprintf('%d %%', Layer.Opacity*100), 'HorizontalAlignment','Left','Position',[Layer.ButtonPos(5,:)+[Layer.ButtonDim(1)*2,0],50,20],'parent',Layer.UIhandle);
Layer.SliderLabel(2) = uicontrol('Style','Text','String',sprintf('%.0f mm', Layer.sigma),'BackgroundColor',Fig.Background,'HorizontalAlignment','Left','Position',[Layer.ButtonPos(5,:)+[Layer.ButtonDim(1)*2,0],50,20],'parent',Layer.UIhandle);
set([Layer.UIhandle, Layer.SliderLabel, Layer.LabelHandle], 'BackgroundColor',Fig.Background);
set(Layer.InputHandle(3), 'BackgroundColor', Layer.Colors(Layer.CurrentStructure, :));


%============= ATLAS OVERLAYS



Fig.AllUIHandles = [Session.UIhandle, Contact.UIhandle, Button.UIhandle, Layer.UIhandle];
set(Fig.Handle, 'Visible', 'On');       % Make main figure visible


end





%% ========================= SUBFUNCTIONS =================================
function h = PlotCircle(x,y,r,c)
th = 0:pi/50:2*pi;
xunit = r * cos(th) + x;
yunit = r * sin(th) + y;
h = plot(xunit, yunit,'Color',c);
end

function h = FillCircle(target,r,N,c)
THETA=linspace(0,2*pi,N);
RHO=ones(1,N)*r;
[X,Y] = pol2cart(THETA,RHO);
X=X+target(1);
Y=Y+target(2);
h=fill(X,Y,c,'EdgeColor','none');
end

function h = PlotSphere(x,y,z,r,c)
[X,Y,Z] = sphere(100);
X = (X*r)+x;
Y = (Y*r)+y;
Z = (Z*r)+z;
h=mesh(X,Y,Z,'FaceColor',c,'EdgeColor','none');
% ellipsoid(x,y,z,1,1,Electrode.ContactLength)
end


%======================= APPLY TRANSFORM MATRIX ===========================
% Transform 3D coordinates of input matrix (Nx3) using Brain.Xform
function [X,Y,Z] = ApplyTform(x,y,z)
    global Brain
    if nargin == 1
        InputSize = size(x);
        if find(size(x)==3)==1
            verts = Brain.Xform*[x; ones(size(x,2),1)];
        elseif find(size(x)==3)==2
            verts = Brain.Xform*[x, ones(size(x,1),1)]';
        elseif size(x,1)==4
            verts = Brain.Xform*x;
     	elseif size(x,2)==4
            verts = Brain.Xform*x';
        end
    elseif nargin == 3
        if size(x,1)==1
            xyz = [x', y', z', ones(numel(z),1)];
        elseif size(x,2)==1
            xyz = [x, y, z, ones(numel(z),1)];
        end
        verts = Brain.Xform*xyz';
    end
    if nargout == 3
        X = verts(1,:);
        Y = verts(2,:);
        Z = verts(3,:);
    elseif nargout == 1
        X = verts(1:3,:);
        if size(X)~= InputSize
            X = X';
        end
    end
end


%============================== DRAW 2D GRID ==============================
function Grid = Draw2DGrid(Grid,Position)
    global Fig
    Grid.Coordinates = [];
    Grid.Object = [];
    Grid.Perm(1) = FillCircle(Position([1,2]),Grid.OuterRadius,100,'y');
    hold on;
  	Grid.Perm(2) = plot([0 0],[-Grid.OuterRadius,Grid.OuterRadius],'-k');
    Grid.Perm(3) = plot([-Grid.OuterRadius,Grid.OuterRadius],[0 0],'-k');
    try                                                                 % 'PickableParts' line propoerty from R2014a
        set(Grid.Perm([2,3]),'hittest','off','PickableParts','none');
    end
    for i = 1:Grid.HolesPerDim
        for h = 1:Grid.HolesPerColumn(i)
            x = ((-((Grid.HolesPerColumn(i)-1)/2)+(h-1))*Grid.InterHoleSpacing);
            y = ((((Grid.HolesPerDim+1)/2)-i)*Grid.InterHoleSpacing);
            r = Grid.HoleDiameter/2;
            Grid.Object(end+1) = PlotCircle(x,y,r,'k');
            Grid.Coordinates(end+1,:) = [x,y];
        end
    end
%     GridParent = hgtransform('Parent',gca);
%     set(GridObject,'Parent',GridParent);
    grid on;
    axis equal tight;
    set(gca,'XTick',-8:2:8,'XColor',[0 0 0]);
    set(gca,'YTick',-8:2:8,'YColor',[0 0 0]);
    set(gca,'color',Fig.AxesBkgColor(1,:));
    Labels(1) = xlabel('Medial-Lateral','Fontsize',Fig.FontSize);                                        
    Labels(2) = ylabel('Posterior-Anterior','Fontsize',Fig.FontSize);
    set(Grid.Object,'ButtonDownFcn',@GridClickCallback);                 	% Set callback function for grid hole selection via mouse
end


%=========================== DRAW GUIDE TUBE ==============================
function GT = DrawGuidetube(Target, Electrode)
    global Fig Grid Brain
    if isfield(Electrode,'GT')
        if ~isempty(Electrode.GT)
            for m = 1:numel(Electrode.GT)
                if ishandle(Electrode.GT(m))
                    delete(Electrode.GT(m));
                end
            end
            Electrode.GT=[];
        end
    end
    GT = [];
    for h = 2:4
     	set(Fig.Handle, 'currentaxes', Fig.PlotHandle(h));
        
        %========== draw guide tube top
        [X,Y,Z] = cylinder(Grid.HoleDiameter,100);
        X = X+Target(1);
        Y = Y+Target(2);
        Z = (Z*Grid.GuideTop)+Grid.Width;
    	fvc = surf2patch(X,Y,Z);
        fvc.vertices = ApplyTform(fvc.vertices);
        GT(end+1) = patch('Faces',fvc.faces,'Vertices',fvc.vertices,'FaceColor',Electrode.GuideColor,'EdgeColor','none');
        
        %========= Draw guide tube shaft
        [X,Y,Z] = cylinder(Grid.HoleDiameter/2,100);
        X = X+Target(1);
        Y = Y+Target(2);
        Z = (Z*-Grid.GuideLength)+Grid.Width;
        fvc = surf2patch(X,Y,Z);
        fvc.vertices = ApplyTform(fvc.vertices);
        GT(end+1) = patch('Faces',fvc.faces,'Vertices',fvc.vertices,'FaceColor',Electrode.GuideColor,'EdgeColor','none');
        alpha(GT, Electrode.GuideAlpha);
    end

end

%=========================== DRAW ELECTRODE ===============================
function Electrode = DrawElectrode(Target, Electrode)
    global Fig Grid Brain Layer
    
    %========================= 2D grid view    
    if isfield(Electrode,'E') && isgraphics(Electrode.E{1}(1))
        CurrXData = get(Electrode.E{1}(1), 'Xdata');
        CurrYData = get(Electrode.E{1}(1), 'Ydata');
        NewXData = CurrXData + diff([mean(CurrXData), Target(1)]);
        NewYData = CurrYData + diff([mean(CurrYData), Target(2)]);
        set(Electrode.E{1}(1), 'Xdata', NewXData, 'Ydata', NewYData);
        set(Electrode.E{1}(2), 'Xdata', repmat(Target(1),[1,2]));
        set(Electrode.E{1}(3), 'Ydata', repmat(Target(2),[1,2]));
    elseif ~isfield(Electrode,'E') || ~isgraphics(Electrode.E{1}(1))
        set(Fig.Handle, 'currentaxes', Fig.PlotHandle(1));
        Electrode.E{1}(1) = FillCircle(Target([1,2]),Grid.HoleDiameter/2,100,'r');
        Electrode.E{1}(2) = plot(repmat(Target(1),[1,2]),[-Grid.OuterRadius,Grid.OuterRadius],'-r');
        Electrode.E{1}(3) = plot([-Grid.OuterRadius,Grid.OuterRadius],repmat(Target(2),[1,2]),'-r');
        try
            set(Electrode.E{1}([2,3]),'hittest','off','PickableParts','none');
        end
	end
            
    %========================= 3D views
    [X,Y,Z] = cylinder(Electrode.Diameter/2,100);           % Electrode shaft
    X = X+Target(1);
    Y = Y+Target(2);
    Z1 = (Z*(Electrode.Length-Electrode.TipLength))-Electrode.CurrentDepth+Electrode.TipLength;
    fvc1 = surf2patch(X,Y,Z1);
    fvc1.vertices = ApplyTform(fvc1.vertices);
    
    [X2,Y2,Z2] = cylinder([0 Electrode.Diameter/2]);        % Electrode tip
    X2 = X2+Target(1);
    Y2 = Y2+Target(2);
    Z2 = (Z2*Electrode.TipLength)-Electrode.CurrentDepth;
    fvc2 = surf2patch(X2,Y2,Z2);
    fvc2.vertices = ApplyTform(fvc2.vertices);
    
    [X3,Y3,Z3] = cylinder(Electrode.Diameter*0.55,100);     % Electrode contacts
    X3 = X3+Target(1);
    Y3 = Y3+Target(2);
        
    %=========== FOR EACH SLICE VIEW AXES...
    for fh = 2:4
        if numel(Electrode.E)>=fh
            set(Electrode.E{fh}(1),'Vertices',fvc1.vertices);
            set(Electrode.E{fh}(2),'Vertices',fvc2.vertices);
        else
            set(Fig.Handle, 'currentaxes', Fig.PlotHandle(fh));
            Electrode.E{fh}(1) = patch('Faces',fvc1.faces,'Vertices',fvc1.vertices,'FaceColor',Electrode.MRIColor,'EdgeColor','none');
            Electrode.E{fh}(2) = patch('Faces',fvc2.faces,'Vertices',fvc2.vertices,'FaceColor',Electrode.MRIColor,'EdgeColor','none');
        end
        
        %=========== DRAW CONTACTS IN MAIN SLICE VIEW
        if fh == 4
            if exist('isgraphics.m','file')
                CurrentHandles = find(isgraphics(Electrode.E{4}));                  % Find valid graphics handles
                NoCurrentContacts = numel(CurrentHandles)-2;                        % How many contacts currently exist?
            else
                NoCurrentContacts = numel(ishandle(Electrode.E{4}))-2;                
            end
            for c = 1:max([Electrode.ContactNumber, NoCurrentContacts])             % Loop through max number
                Z3 = (Z*Electrode.ContactDiameter)-Electrode.CurrentDepth+Electrode.TipLength+(c-1)*Electrode.ContactSpacing;
                [xa ya za] = ApplyTform(X3(1,:),Y3(1,:),Z3(1,:));
                [xb yb zb] = ApplyTform(X3(2,:),Y3(2,:),Z3(2,:));
                if c <= NoCurrentContacts && c <= Electrode.ContactNumber       % 1) Contact # already exists: move it
                    set(Electrode.E{fh}(2+c), 'xdata', [xa; xb], 'ydata', [ya;yb], 'zdata', [za;zb]);
                elseif c > NoCurrentContacts && c <= Electrode.ContactNumber    % 2) Contact # doesn't exist: create it
                    Electrode.E{fh}(2+c) = mesh([xa; xb], [ya;yb], [za;zb],'FaceColor',Electrode.ContactColor,'EdgeColor','none');
                    hold on;
                elseif c > Electrode.ContactNumber && c <= NoCurrentContacts    % Contact numbers > requested number: delete it
                	delete(Electrode.E{fh}(2+c));
                end
            end
%          	drawnow;
        end

    end
    DrawCurrentContact(Target, Electrode);
    
    %========================= Plot corsshair planes in 3D view
    if Brain.PlanesOn == 1
        set(Fig.Handle, 'currentaxes', Fig.PlotHandle(2));
        Xlim = get(gca,'Xlim');
        Ylim = get(gca,'Ylim');
        Zlim = get(gca,'Zlim');     
        X = Target(1);
        Y = Target(2);
        Z = -Electrode.CurrentDepth+Electrode.TipLength+((Electrode.CurrentSelected-1)*Electrode.ContactSpacing);
        [X, Y, Z] = ApplyTform(X,Y,Z);
        if numel(Electrode.E)>=5
            set(Electrode.E{5}([1,3]),'Xdata', repmat(X,[1,4]), 'Ydata', [Ylim, Ylim([2,1])], 'Zdata', [Zlim(1),Zlim(1),Zlim(2),Zlim(2)]);
            set(Electrode.E{5}(2),'Xdata', [Xlim, Xlim([2,1])], 'Ydata', repmat(Y,[1,4]), 'Zdata', [Zlim(1),Zlim(1),Zlim(2),Zlim(2)]);
            set(Electrode.E{5}(4),'Xdata', [Xlim, Xlim([2,1])], 'Ydata', [Ylim(1),Ylim(1),Ylim(2),Ylim(2)], 'Zdata', repmat(Z,[1,4]));
        else
            Electrode.E{5}(1) = patch(repmat(X,[1,4]), [Ylim, Ylim([2,1])], [Zlim(1),Zlim(1),Zlim(2),Zlim(2)],'r');
            Electrode.E{5}(2) = patch([Xlim, Xlim([2,1])], repmat(Y,[1,4]), [Zlim(1),Zlim(1),Zlim(2),Zlim(2)],'r');
            set(Fig.Handle, 'currentaxes', Fig.PlotHandle(3));
            Electrode.E{5}(3) = patch(repmat(X,[1,4]), [Ylim, Ylim([2,1])], [Zlim(1),Zlim(1),Zlim(2),Zlim(2)],'r');
            Electrode.E{5}(4) = patch([Xlim, Xlim([2,1])], [Ylim(1),Ylim(1),Ylim(2),Ylim(2)], repmat(Z,[1,4]),'r');
            set(Electrode.E{5},'FaceAlpha',Brain.PlanesAlpha);
            set(Electrode.E{5},'Facecolor',Brain.PlanesRGB);
            set(Electrode.E{5},'EdgeColor',Brain.PlanesRGB);
        end
    end
    
    %============ Set axis limits for main slice view
    if Layer.ZoomOn==1
        if exist('isgraphics.m','file')
            Contacts = find(isgraphics(Electrode.E{4}));
        else
            Contacts = find(ishandle(Electrode.E{4}));
        end
        ZoomedXlims = sort([mean(mean(get(Electrode.E{4}(3), 'xdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'xdata'),2))]);
        ZoomedYlims = sort([mean(mean(get(Electrode.E{4}(3), 'ydata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'ydata'),2))]);
        ZoomedZlims = sort([mean(mean(get(Electrode.E{4}(3), 'zdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'zdata'),2))]);
        set(Fig.PlotHandle(4), 'xlim', ZoomedXlims+[-Layer.ZoomLevel, Layer.ZoomLevel],'ylim', ZoomedYlims+[-Layer.ZoomLevel, Layer.ZoomLevel], 'zlim', ZoomedZlims+[-Layer.ZoomLevel, Layer.ZoomLevel]);

    elseif Layer.ZoomOn==0                                     %====== Zoom OUT
        set(Fig.PlotHandle(4),'xlim', Layer.MRI(1).BoundsSagMM);
        set(Fig.PlotHandle(4),'ylim', Layer.MRI(1).BoundsCorMM);
        set(Fig.PlotHandle(4),'zlim', Layer.MRI(1).BoundsAxMM);
    end
end


 %================ PLOT CROSSHAIRS ON MRI AT CURRENT CONTACT ==============
function DrawCurrentContact(Target, Electrode)
	global Fig Grid MRI Brain Atlas Layer
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(4));       	% Select axes #4 to display sagittal MRI slice
    X = Target(1);
    Y = Target(2);
    Z = -Electrode.CurrentDepth+Electrode.TipLength+(Electrode.CurrentSelected-1)*Electrode.ContactSpacing;
    [X, Y, Z] = ApplyTform(X,Y,Z);
    [CurrXpos,CurrYpos,CurrZpos] = deal(X,Y,Z);
    Electrode.Contact.CurrPos = [CurrXpos,CurrYpos,CurrZpos];
    if isfield(Layer,'XhairHandle')                             % Check whether a handle to crosshairs exists
        if ishandle(Layer.XhairHandle(1))                        
            set(Layer.XhairHandle(1),'xdata', [CurrXpos,CurrXpos], 'ydata', [CurrYpos,CurrYpos]);
            set(Layer.XhairHandle(2),'xdata', [CurrXpos,CurrXpos], 'zdata', [CurrZpos,CurrZpos]);
            set(Layer.XhairHandle(3),'ydata', [CurrYpos,CurrYpos], 'zdata', [CurrZpos,CurrZpos]);
        end
    else
        Layer.XhairHandle(1) = plot3([CurrXpos,CurrXpos],[CurrYpos,CurrYpos],Layer.MRI(1).BoundsAxMM,'-r');  
        hold on;
        Layer.XhairHandle(2) = plot3([CurrXpos,CurrXpos],Layer.MRI(1).BoundsCorMM,[CurrZpos,CurrZpos],'-r');
        Layer.XhairHandle(3) = plot3(Layer.MRI(1).BoundsSagMM,[CurrYpos,CurrYpos],[CurrZpos,CurrZpos],'-r');
    end 
end


%=========================== DRAW 2D MRI SLICE ============================
function M = DrawMRI(Target, Electrode)
    global Fig Grid Brain Atlas Layer
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(4));                                                          % Select axes #4 to display MRI slice
 	Z = -Electrode.CurrentDepth+Electrode.TipLength+(Electrode.CurrentSelected-1)*Electrode.ContactSpacing;
 	SlicePosMM = ApplyTform([Target, Z, 1]);                                                                    % Get current selected contact coordinates (mm)
  	SliceThicknessMM = 1;
    
        
    %=============== FOR EACH STRUCTURE/ LAYER...    
    for Ln = [1,3:numel(Layer.MRI)]
        
        %=============== GET SLICE INDEX
        Layer.MRI(Ln).CurrentSlice = Layer.MRI(Ln).OriginVox + round(SlicePosMM./Layer.MRI(Ln).VoxelDim);           % Get slice index of current selected contact
        X = 1:Layer.MRI(Ln).DimVox(1);
        Y = 1:Layer.MRI(Ln).DimVox(2);
        Z = 1:Layer.MRI(Ln).DimVox(3);
        switch Layer.CurrentSliceView
            case 1      %==================== SAGITTAL
                X = Layer.MRI(Ln).CurrentSlice(Layer.CurrentSliceView);
               	xPos = repmat(SlicePosMM(Layer.CurrentSliceView),[2,2]) - Layer.MRI(Ln).VoxelDim(Layer.CurrentSliceView);
                yPos = [Layer.MRI(Ln).BoundsCorMM; Layer.MRI(Ln).BoundsCorMM];
                zPos = repmat(Layer.MRI(Ln).BoundsAxMM,[2,1])';
            case 2      %==================== CORONAL
                Y = Layer.MRI(Ln).CurrentSlice(Layer.CurrentSliceView);
                xPos = [Layer.MRI(Ln).BoundsSagMM; Layer.MRI(Ln).BoundsSagMM];
                yPos = repmat(SlicePosMM(Layer.CurrentSliceView),[2,2])-Layer.MRI(Ln).VoxelDim(Layer.CurrentSliceView);
                zPos = repmat(Layer.MRI(Ln).BoundsAxMM,[2,1])';
            case 3      %==================== AXIAL
                Z = Layer.MRI(Ln).CurrentSlice(Layer.CurrentSliceView);
               	xPos = repmat(Layer.MRI(Ln).BoundsSagMM,[2,1])';
                yPos = [Layer.MRI(Ln).BoundsCorMM; Layer.MRI(Ln).BoundsCorMM];
                zPos = repmat(SlicePosMM(Layer.CurrentSliceView),[2,2])-Layer.MRI(Ln).VoxelDim(Layer.CurrentSliceView);
        end
        %=============== GET SLICE DATA
        CurrentMRISlice = squeeze(Layer.MRI(Ln).img(X,Y,Z));
        if ~isempty(Layer.MRI(Ln).AlphaMaskVolume)
            CurrentAlpha = squeeze(Layer.MRI(Ln).AlphaMaskVolume(X,Y,Z))*Layer.Opacity(Ln);                   % Get current slice alpha layer
        else
            CurrentAlpha = [];
        end
        %=============== REORIENT SLICE
      	if Layer.CurrentSliceView <3
            CurrentMRISlice = flipud(rot90(CurrentMRISlice));
            CurrentAlpha = flipud(rot90(CurrentAlpha));
        end
        %=============== APPLY FILTERING
        if Layer.sigma(Ln) > 0                                                                                                  	% If filter kernel size is non-zero
            Layer.G{Ln} = fspecial('gaussian',Layer.hsize,Layer.sigma(Ln));                                                       	% create default smoothing kernel
            CurrentMRISlice = imfilter(CurrentMRISlice,Layer.G{Ln},'same');          
            if ~isempty(CurrentAlpha)
                CurrentAlpha = imfilter(CurrentAlpha,Layer.G{Ln},'same');                                                        	% Apply Gaussian filter to atlas slice (implies probability)
            end
        end
        %=============== DRAW SLICE
        if ~isfield(Layer.MRI,'ImageHandle')                                        %=============== If image handle does not yet exist...
            Layer.MRI(Ln).ImageHandle = surf(xPos,yPos,zPos,'CData',CurrentMRISlice,'FaceColor','texturemap','EdgeColor','none');  	% Draw MRI slice to axes
            hold on;
            if ~isempty(CurrentAlpha)
                set(Layer.MRI(Ln).ImageHandle,'FaceAlpha','texturemap', 'alphadata', CurrentAlpha);                                        % Set slice alpha in axes
            end
%             set(Layer.MRI(Ln).ImageHandle,'ButtonDownFcn',@MRIClickCallback);                                                     	% Set callback function for contact selection via mouse                                                   
            if Layer.On(Ln) == 0
                set(Layer.MRI(Ln).ImageHandle, 'visible', 'off');
            end
       
        elseif isfield(Layer.MRI,'ImageHandle')                                     %=============== If image handle already exists...
            if ishandle(Layer.MRI(Ln).ImageHandle)
                set(Layer.MRI(Ln).ImageHandle, 'CData', CurrentMRISlice, 'xdata', xPos, 'ydata', yPos, 'zdata', zPos);    	% Update the cdata for the currents layer
                if ~isempty(CurrentAlpha)
                    set(Layer.MRI(Ln).ImageHandle, 'alphadata', CurrentAlpha);                                          	% Update the alpha for the currents layer
                end
            end
        end
        
    end
    M = Layer.MRI(1).ImageHandle;    
    
        
    %===================== AXIS SETTINGS
  	axis equal tight xy;
    colormap(Layer.Colormap);
    set(gca,'Clim',[0 2]);
    set(gca,'TickDir','out');
    if Fig.CoordinatesInMM == 1
        title(sprintf('[XYZ] = %.2f, %.2f, %.2f mm', SlicePosMM), 'fontsize',16, 'units','normalized','pos',[0 1.01],'HorizontalAlignment','left');
    elseif Fig.CoordinatesInMM == 0
        SlicePosVox = Layer.MRI(1).OriginVox + round(SlicePosMM./Layer.MRI(1).VoxelDim);
        title(sprintf('[XYZ] = %d, %d, %d voxels', SlicePosVox), 'fontsize',16, 'units','normalized','pos',[0 1.01],'HorizontalAlignment','left');
    end
    

  	if Layer.ZoomOn==1                          %================== ZOOM ON
        if exist('isgraphics.m','file')
            Contacts = find(isgraphics(Electrode.E{4}));
        else
            Contacts = find(ishandle(Electrode.E{4}));
        end
        ZoomedXlims = sort([mean(mean(get(Electrode.E{4}(3), 'xdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'xdata'),2))]);
        ZoomedYlims = sort([mean(mean(get(Electrode.E{4}(3), 'ydata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'ydata'),2))]);
        ZoomedZlims = sort([mean(mean(get(Electrode.E{4}(3), 'zdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'zdata'),2))]);
        set(Fig.PlotHandle(4), 'xlim', ZoomedXlims+[-Layer.ZoomLevel, Layer.ZoomLevel],'ylim', ZoomedYlims+[-Layer.ZoomLevel, Layer.ZoomLevel], 'zlim', ZoomedZlims+[-Layer.ZoomLevel, Layer.ZoomLevel]);

    elseif Layer.ZoomOn==0                  	%================== ZOOM OFF
        set(Fig.PlotHandle(4),'xlim', Layer.MRI(1).BoundsSagMM);
        set(Fig.PlotHandle(4),'ylim', Layer.MRI(1).BoundsCorMM);
        set(Fig.PlotHandle(4),'zlim', Layer.MRI(1).BoundsAxMM);
    end
   	switch Layer.CurrentSliceView
        case 1      %==================== SAGITTAL
            view(90,0);
            Layer.Xlims = [xPos(1,1)-SliceThicknessMM, xPos(1,1)+SliceThicknessMM];
            set(Fig.PlotHandle(4),'xlim', Layer.Xlims);
        case 2      %==================== CORONAL
            view(180,0);
            Layer.Ylims = [yPos(1,1)-SliceThicknessMM, yPos(1,1)+SliceThicknessMM];
            set(Fig.PlotHandle(4),'ylim', Layer.Ylims);
        case 3      %==================== AXIAL
            view(90,90);
            Layer.Zlims = [zPos(1,1)-SliceThicknessMM, zPos(1,1)+SliceThicknessMM];
            set(Fig.PlotHandle(4),'zlim', Layer.Zlims);
    end
    xlabel('M - L (mm)','Fontsize',Fig.FontSize);
    ylabel('P - A (mm)','Fontsize',Fig.FontSize);
    zlabel('I - S (mm)','Fontsize',Fig.FontSize);
end


%========================= DRAW 3D BRAIN SURFACE ==========================
function Brain = DrawBrain3D(Brain, Electrode, Grid)
    global Fig Target Surface
    figure(Fig.Handle);
    
%     if ~isfield(Brain,'Object')
        [v,f] = read_vtk(Surface.VTKfile);
        FV.vertices = v';
        FV.faces = f';
        FV.facevertexcdata = Brain.RGB;
        FV.facecolor = 'flat';
        FV.facealpha = Brain.Alpha;
        FV.edgecolor = 'none';    
        if ~isfield(Brain,'Object')
            Brain.Object = patch(FV,'EdgeColor','none');
        elseif isfield(Brain,'Object')
            DeleteHandles = [];
            for h = 1:numel(Brain.Object)
                if ~ishandle(Brain.Object(h))
                    DeleteHandles(end+1) = h;
                end
            end
            Brain.Object(DeleteHandles) = [];
            Brain.Object(end+1) = patch(FV,'EdgeColor','none');
        end
        hold on;
        camlight right;
        lighting phong;
        colormap bone;
        axis(gca,'vis3d');                                      % Maintain axes ratio (do not scale)     
        Brain.Labels(1) = xlabel('Medial-Lateral','Fontsize',Fig.FontSize);                                        
        Brain.Labels(2) = ylabel('Posterior-Anterior','Fontsize',Fig.FontSize);
        Brain.Labels(3) = zlabel('Inferior-Superior','Fontsize',Fig.FontSize);
        grid on;
        axis equal;
     	set(Brain.Object,'SpecularStrength',Brain.Specular,'AmbientStrength',Brain.Ambient,'DiffuseStrength',Brain.Diffuse);
%     end

    %======================== LOAD STUCTURES ==============================
%     if ~isfield(Surface,'Object')
%         cd(Surface.StructFolder);
%         Surface.StructVTKs = dir('*.vtk');
%         Surface.ObjectVis = zeros(1,numel(Surface.StructVTKs));
%         for s = 1:numel(Surface.StructVTKs)
%             [v,f] = read_vtk(Surface.StructVTKs(s).name);
%             FV.vertices = v';
%             FV.faces = f';
%             FV.facevertexcdata = Brain.SurfaceColors(s,:);
%             FV.facecolor = 'flat';
%             FV.facealpha = 1;
%             FV.edgecolor = 'none';    
%             Surface.Object(s) = patch(FV,'EdgeColor','none');
%             set(Surface.Object(s),'Facecolor',Brain.SurfaceColors(s,:));
%             if Surface.ObjectVis(s) == 1
%                 set(Surface.Object(s),'Visible','on');
%             elseif Surface.ObjectVis(s) == 0
%                 set(Surface.Object(s),'Visible','off');
%             end
%         end
%     end

    %=============== Draw chamber & grid holes
    hold on;
    GridFV.vertices = ApplyTform(Grid.vertices);
    GridFV.faces = Grid.faces;
    Brain.Chamber = patch(GridFV, 'FaceColor', Grid.RGB, 'EdgeColor', 'none');
%     set(Brain.Chamber,'FaceLighting','phong');%'FaceColor','interp',
    set(Brain.Object,'FaceVertexAlphaData',Brain.Alpha);
  	set(Brain.Object,'FaceAlpha',Brain.Alpha);
  	set(Brain.Object,'Facecolor',Brain.RGB);
%     whitebg(Fig.AxesBkgColor);
    set(gca,'xlim',Surface.Xlim);
    set(gca,'ylim',Surface.Ylim);
    set(gca,'zlim',Surface.Zlim);
    box on;
    grid on;
    set(gca,'color',Fig.AxesBkgColor(1,:));
    
    % Settings
    set(Brain.Object,'Visible','on');
    set(Brain.Object,'HitTest','on');
    drawnow

end


%======================= DRAW CONTACTS SCHEMATIC ==========================
function Electrode = DrawContacts(Electrode)
    global Fig
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(5));                                      % Set current axes to electrode contact schematic
    cla;                                                                                    % Clear axes
    Electrode.ContactRadius = 2;                                                            % Set schematic dimension parameters...
    ContactSpacing = 2*Electrode.ContactRadius+2;
    ShaftRadius = 5;
    TipLength = 20;
    FullLength = (Electrode.ContactNumber*ContactSpacing)+TipLength;                        
    Electrode.ContactPos = linspace(TipLength,FullLength-(Electrode.ContactRadius*2), Electrode.ContactNumber);
    X = [0 -ShaftRadius -ShaftRadius ShaftRadius ShaftRadius];
    Y = [0 TipLength FullLength FullLength TipLength];                                      
    Electrode.C(1) = patch(X,Y,Electrode.Color);                                            % Draw electrode shaft
    hold on;
    for cont = 1:Electrode.ContactNumber                                                 	% For each contact
        Electrode.C(1+cont) = FillCircle([0 Electrode.ContactPos(cont)],Electrode.ContactRadius,100, Electrode.QualityColorMap(Electrode.ContactData(cont)+1,:));
    end
    Electrode.CurrentSelectedHandle = PlotCircle(0,Electrode.ContactPos(Electrode.CurrentSelected),Electrode.ContactRadius,Electrode.SelectionColor);
    set(Electrode.CurrentSelectedHandle,'LineWidth', 2);
    axis equal tight;
    set(gca,'YTick', Electrode.ContactPos, 'YTickLabel', 1:Electrode.ContactNumber);        
    set(gca,'color',Fig.AxesBkgColor(1,:));                                               	% Set axis background to match figure
    set(gca,'xcolor',Fig.Background,'xtick',[]);                                            % Hide x-axis
    set(Electrode.C(2:end),'ButtonDownFcn',@ElectrodeClickCallback);                        % Set callback function for contact selection via mouse
    
    %========== Set context menu for quality rating
    hcmenu = uicontextmenu;
    for i = 1:size(Electrode.QualityColorMap,1)
        item(i) = uimenu(hcmenu,'Label',num2str(i-1),'Callback',{@ContactContextmenu,i});
    end
    set(Electrode.C(2:end),'uicontextmenu',hcmenu);
    
end



%% =========================== CALLBACKS ==================================

%========================== GRID HOLE SELECTION
function GridClickCallback(objectHandle, eventData)
global Button Target Electrode Grid Layer
    axesHandle  = get(objectHandle,'Parent');
    Grid.CurrentSelected = find(Grid.Object==objectHandle);
    Target = Grid.Coordinates(Grid.CurrentSelected,:);
	Layer.M = DrawMRI(Target, Electrode);                               % Draw current MRI slice
    Electrode = DrawElectrode(Target, Electrode);                       % Move electrode
    Electrode.GT = DrawGuidetube(Target, Electrode);                    % Move guide tube
    for i = 1:2
        set(Button.InputHandle(i),'String',num2str(Target(i)));         % Update grid hole selection in input boxes
    end
end

%========================== CONTACT SELECTION
function ElectrodeClickCallback(objectHandle, eventData)
global Electrode Contact Target
    axesHandle  = get(objectHandle,'Parent');
    coordinates = get(axesHandle,'CurrentPoint');
    Ypos = coordinates(1,2);                                                    
    Electrode.CurrentSelected = find(Electrode.C==objectHandle)-1;              % Find selected contact #
    delete(Electrode.CurrentSelectedHandle);                                    % Delete the previously selected contact highlight
    Electrode.CurrentSelectedHandle = PlotCircle(0,Electrode.ContactPos(Electrode.CurrentSelected),Electrode.ContactRadius,Electrode.SelectionColor);
    set(Electrode.CurrentSelectedHandle,'LineWidth', 2);                        
    set(Contact.InputHandle(1),'String',num2str(Electrode.CurrentSelected));    % Update text to show current contact #
    set(Contact.InputHandle(2),'String',num2str(Electrode.ContactData(Electrode.CurrentSelected)));    % Update text to show current contact value
    DrawCurrentContact(Target, Electrode);                                      % Update plot to show current contact
    DrawMRI(Target, Electrode);
end

%============ UPDATE CONTACT QUALITY RATING
function ContactContextmenu(src,evt, i)
    global Electrode Contact
    set(gco,'FaceColor', Electrode.QualityColorMap(i,:));
   	Electrode.CurrentSelected = find(Electrode.C== gco)-1;  	% Find selected contact #
	Electrode.ContactData(Electrode.CurrentSelected) = i-1;
    set(Contact.InputHandle(2),'String',num2str(Electrode.ContactData(Electrode.CurrentSelected))); 
end

%========================== MRI SELECTION
function MRIClickCallback(objectHandle, eventData)
global Layer
    axesHandle  = get(objectHandle,'Parent');
    pan on; 


end

%========================== UPDATE SESSION PARAMETERS
function SessionParams(hObj, Event, Indx)
global Electrode Session Contact Button Target Defaults
    switch Indx                                                         % If updated variable was...
        case 1      %==================== Subject name
            
            
        case 2      %==================== Session date
            SelectedDate = Electrode.DateStrings(get(hObj,'Value'),:);  % Get selected date string
            if ~strcmp(SelectedDate, date)
                Params = LoadSessionParams(Defaults.HistoryFile, SelectedDate);
                Target = Params.Target;
                Electrode.CurrentDepth = Params.Depth;
                Session.Date = Params.Date;
                Session.ElectrodeID = Params.ElectrodeID;
                Session.GuideLength = Params.GuideLength;
                Session.Details = {Session.Subject,Session.Date,Session.ElectrodeID};
                ElectrodeIDIndx = find(strncmp(Params.ElectrodeID,Electrode.AllTypes, 2));
                set(Session.InputHandle(3), 'value',ElectrodeIDIndx);
                Button.CurrentValues = [Target(1),Target(2),0, 0, Electrode.CurrentDepth, Session.GuideLength];
                for i = 1:numel(Button.CurrentValues)
                    set(Button.InputHandle(i),'String',num2str(Button.CurrentValues(i)));
                end
                Layer.M = DrawMRI(Target, Electrode);
                Electrode.GT = DrawGuidetube(Target, Electrode); 
                Electrode = DrawElectrode(Target, Electrode); 
            end
            
        case 3      %==================== Electrode type
            AllBrands = get(hObj,'String');
            Electrode.Brand = AllBrands{get(hObj,'Value')};
            Electrode.ID = sprintf('%s%d', Electrode.Brand, Electrode.ContactNumber);
            Electrode = GetElectrodeParams(Electrode);                  % Get electrode parameters based on electrode ID
            Electrode = DrawContacts(Electrode);                        
            
            
            
        case 4      %==================== Electrode contacts
             Electrode.ContactNumber = str2num(get(hObj,'String'));
             delete(Electrode.C);
             Electrode.C = [];
             if Electrode.ContactNumber > numel(Electrode.ContactData)
             	Electrode.ContactData(end+1:Electrode.ContactNumber) = 0;
             elseif Electrode.ContactNumber < numel(Electrode.ContactData)
                 Electrode.ContactData((Electrode.ContactNumber+1):end) = [];
             end
             if Electrode.ContactNumber < Electrode.CurrentSelected
                 Electrode.CurrentSelected = Electrode.ContactNumber;
                 set(Contact.InputHandle(1),'String',num2str(Electrode.CurrentSelected));                           % Update text to show current contact #
                 set(Contact.InputHandle(2),'String',num2str(Electrode.ContactData(Electrode.CurrentSelected)));    % Update text to show current contact #
                
             end
             Electrode = DrawContacts(Electrode);                           % Re-draw electrode schematic
             Electrode = DrawElectrode(Target, Electrode);              	% Re-draw 3D electrode objects

    end
end

%========================== UPDATE ELECTRODE POSITION =====================
function ElectrodePos(hObj, Event, Indx)
    global Electrode Target Fig Layer Button Grid
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(1));                  % Set current axes to 3D view
    switch Indx                                                         % If updated variable was...
        case 3                                                          % 3 = Start depth (manual)
            Electrode.StartDepth = str2num(get(hObj,'String'));
            Electrode.CurrentDepth = Electrode.StartDepth+Electrode.MicrodriveDepth;
            set(Button.InputHandle(5),'String',num2str(Electrode.CurrentDepth));
            
        case 4                                                          % 4 = EPS depth
            Electrode.MicrodriveDepth = str2num(get(hObj,'String'));
            Electrode.CurrentDepth = Electrode.StartDepth+Electrode.MicrodriveDepth;
            set(Button.InputHandle(5),'String',num2str(Electrode.CurrentDepth));
            
        case 5                                                          % 5 = Total depth
            Electrode.CurrentDepth = str2num(get(hObj,'String'));
            
            
        case 6
            Session.GuideLength = str2num(get(hObj,'String'));          % 6 = Guide tube length
            Grid.GuideLength = Session.GuideLength;
            delete(Electrode.GT);                                     	% Delete current guide tube object
            Electrode.GT = DrawGuidetube(Target, Electrode);        	% Draw new guide tube object
    end
    if Indx < 3
        Target(Indx) = str2num(get(hObj,'String'));
        delete(Electrode.GT);                                           % Delete current guide tube object
      	Electrode.GT = DrawGuidetube(Target, Electrode);                % Draw new guide tube object
    end
    if Indx <=5                                                         % If contact position changed...
        Layer.M = DrawMRI(Target, Electrode);                           % Draw new MRI sections
    end
    Electrode = DrawElectrode(Target, Electrode);                       % Draw new electrode object
    DrawCurrentContact(Target, Electrode);
    drawnow;                                                            % Refresh figure
end

%========================= TURN 3D SURFACES ON/OFF ========================
function SurfaceSelect(hObj, Event, Indx)
    global Fig Surface Brain
    
    Surface.ObjectVis(Indx) = ~Surface.ObjectVis(Indx);
    if Surface.ObjectVis(Indx) == 1
        set(Surface.Object(s),'Visible','on');
    elseif Surface.ObjectVis(s) == 0
        set(Surface.Object(s),'Visible','off');
    end
end


%======================== ATLAS LAYER CONTROLS ============================
function LayerView(hObj, Evnt, Indx)
    global Layer Fig Target Electrode
    switch Indx
        case 1                          %================== Change slice view
            Layer.CurrentSliceView = get(hObj,'Value');
            
        
        case 2                          %================== Change selected stucture
            Layer.CurrentStructure = get(hObj,'Value');
            set(Layer.InputHandle(3), 'BackgroundColor', Layer.Colors(Layer.CurrentStructure, :));
            set(Layer.InputHandle(4), 'value', Layer.Opacity(Layer.CurrentStructure)); 
            set(Layer.InputHandle(5), 'value', Layer.Smoothing(Layer.CurrentStructure));
          	if Layer.CurrentStructure == 1
                set(Layer.InputHandle(3), 'enable','off');
                set(Layer.InputHandle(5), 'enable','off');
                set(Layer.InputHandle(6), 'enable','off');
            else
                set(Layer.InputHandle(3), 'enable','on');
                set(Layer.InputHandle(5), 'enable','on');
                set(Layer.InputHandle(6), 'enable','on');
            end
            
        case 3                          %================== Change current stuctures color
            Layer.Colors(Layer.CurrentStructure,:) = get(hObj,'BackgroundColor');
            Layer.Colors(Layer.CurrentStructure,:) = uisetcolor(Layer.Colors(Layer.CurrentStructure,:));
            set(Layer.InputHandle(3), 'BackgroundColor', Layer.Colors(Layer.CurrentStructure, :));
            
        case 4                          %============== Update layer transparency
            Layer.Opacity(Layer.CurrentStructure) = get(hObj,'Value');
            ValueString = sprintf('%.0f %%', Layer.Opacity(Layer.CurrentStructure)*100);
            set(Layer.SliderLabel(1), 'String',ValueString);

        case 5                    	%============== Update gaussian blur
            Layer.sigma(Layer.CurrentStructure) = max([get(hObj,'Value')*Layer.SigmaMax, Layer.SigmaMin]);
            ValueString = sprintf('%.1f mm', Layer.sigma(Layer.CurrentStructure));
            set(Layer.SliderLabel(2), 'String',ValueString);
            if Layer.sigma > 0
                Layer.G{Layer.CurrentStructure} = fspecial('gaussian',Layer.hsize,Layer.sigma(Layer.CurrentStructure));
            end
        case 6                      %============== Toggle layer fill/ outline
            Layer.On(Layer.CurrentStructure) = get(hObj,'Value');
            if Layer.On(Layer.CurrentStructure) == 1                                    % If layer was turned on...
                set(Layer.MRI(Layer.CurrentStructure).ImageHandle,'visible','on');      % make visible
            elseif Layer.On(Layer.CurrentStructure) == 0                                % If layer was turned off...
                set(Layer.MRI(Layer.CurrentStructure).ImageHandle,'visible','off'); 	% make invisible
            end
    end
    Layer.M = DrawMRI(Target, Electrode);
    if Indx==1
        DrawCurrentContact(Target, Electrode);
    end
    
end



%======================== CONTACT OPTIONS =================================
function ContactSelect(hObj, Event, Indx)
    global Contact Fig Brain Session Electrode Defaults Target Layer

    switch Indx
        
        case 1  %============== New contact selected
            Electrode.CurrentSelected = str2num(get(hObj,'String'));
            if Electrode.CurrentSelected > Electrode.ContactNumber
                Electrode.CurrentSelected = Electrode.ContactNumber;
                set(Contact.InputHandle(1),'String',num2str(Electrode.CurrentSelected));
            elseif Electrode.CurrentSelected < 1
                Electrode.CurrentSelected = 1;
                set(Contact.InputHandle(1),'String',num2str(Electrode.CurrentSelected));
            end
            set(Contact.InputHandle(2),'String',num2str(Electrode.ContactData(Electrode.CurrentSelected)));
            set(Fig.Handle, 'currentaxes', Fig.PlotHandle(5));   
            delete(Electrode.CurrentSelectedHandle);          
            Electrode.CurrentSelectedHandle = PlotCircle(0,Electrode.ContactPos(Electrode.CurrentSelected),Electrode.ContactRadius,Electrode.SelectionColor);
            set(Electrode.CurrentSelectedHandle,'LineWidth', 2);
            DrawCurrentContact(Target, Electrode);
            
        case 2  %============== New contact rating provided
            Electrode.ContactData(Electrode.CurrentSelected) = str2num(get(hObj,'String'));
            if Electrode.ContactData(Electrode.CurrentSelected) > numel(Electrode.QualityColorMap)
                Electrode.ContactData(Electrode.CurrentSelected) = numel(Electrode.QualityColorMap);
                set(Contact.InputHandle(2),'String',num2str(Electrode.ContactData(Electrode.CurrentSelected)));
            elseif Electrode.ContactData(Electrode.CurrentSelected) < 0
                Electrode.ContactData(Electrode.CurrentSelected) = 0;
                set(Contact.InputHandle(2),'String',num2str(Electrode.ContactData(Electrode.CurrentSelected)));
            end
            QualityColor = Electrode.QualityColorMap(Electrode.ContactData(Electrode.CurrentSelected)+1,:);
            set(Electrode.C(Electrode.CurrentSelected+1), 'FaceColor', QualityColor);
            
            
        case 3  %============== Adjust MRI view zoom level
            Layer.ZoomLevel = str2num(get(hObj,'string'));
            if Layer.ZoomOn==1                                         %====== Zoom IN
                if exist('isgraphics.m','file')
                    Contacts = find(isgraphics(Electrode.E{4}));
                else
                    Contacts = find(ishandle(Electrode.E{4}));
                end
                ZoomedXlims = sort([mean(mean(get(Electrode.E{4}(3), 'xdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'xdata'),2))]);
                ZoomedYlims = sort([mean(mean(get(Electrode.E{4}(3), 'ydata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'ydata'),2))]);
                ZoomedZlims = sort([mean(mean(get(Electrode.E{4}(3), 'zdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'zdata'),2))]);
                set(Fig.PlotHandle(4), 'xlim', ZoomedXlims+[-Layer.ZoomLevel, Layer.ZoomLevel],'ylim', ZoomedYlims+[-Layer.ZoomLevel, Layer.ZoomLevel], 'zlim', ZoomedZlims+[-Layer.ZoomLevel, Layer.ZoomLevel]);
            end
            
        case 4  %============== Toggle MRI view zoom to contacts
            Layer.ZoomOn = get(hObj,'value');
            if Layer.ZoomOn==1                                         %====== Zoom IN
                if exist('isgraphics.m','file')
                    Contacts = find(isgraphics(Electrode.E{4}));
                else
                    Contacts = find(ishandle(Electrode.E{4}));
                end
                ZoomedXlims = sort([mean(mean(get(Electrode.E{4}(3), 'xdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'xdata'),2))]);
                ZoomedYlims = sort([mean(mean(get(Electrode.E{4}(3), 'ydata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'ydata'),2))]);
                ZoomedZlims = sort([mean(mean(get(Electrode.E{4}(3), 'zdata'),2)), mean(mean(get(Electrode.E{4}(Contacts(end)), 'zdata'),2))]);
                set(Fig.PlotHandle(4), 'xlim', ZoomedXlims+[-Layer.ZoomLevel, Layer.ZoomLevel],'ylim', ZoomedYlims+[-Layer.ZoomLevel, Layer.ZoomLevel], 'zlim', ZoomedZlims+[-Layer.ZoomLevel, Layer.ZoomLevel]);
                
            elseif Layer.ZoomOn==0                                     %====== Zoom OUT
                set(Fig.PlotHandle(4),'xlim', Layer.MRI(1).BoundsSagMM);
                set(Fig.PlotHandle(4),'ylim', Layer.MRI(1).BoundsCorMM);
            	set(Fig.PlotHandle(4),'zlim', Layer.MRI(1).BoundsAxMM);
            end

        case 4  %============== Reset MRI view to slice containing current contact
        	
        	
            
    end
end


function DisplayAtlasStructure
global Layer
    SelectedIndx = GetStructureIndex(1);                                            % Get indices of atlas structures (bilateral)
    Layer.MRI(2).StructVolume = zeros(size(Layer.MRI(2).nii.img));                  % Create a volume the same size as the atlas
    StructureVals = linspace(0,1,numel(SelectedIndx)/2);                            % Create unique value for each struture (0-1)
    for n = 1:(numel(SelectedIndx)/2)
        Layer.MRI(2).StructVolume(ismember(Layer.MRI(2).nii.img,SelectedIndx([(n*2)-1,n*2]))) = StructureVals(n);  	% Fill the selected structures
    end
    
    
end




%% ======================== MENU BAR CALLBACKS ============================


%========================== FILE MENU CALLBACK ============================
function FileSelect(hObj, Event, Indx, Indx2)
    global Electrode Target Fig Session Button Defaults Layer
    switch Indx
        
        case 1          %============================= LOAD previous session
%             if exist(Defaults.HistoryFile,'file')==0                                     	% If default Excel file doesntt exist...
%               	[Filename, Pathname, Indx] = uiputfile('*.xls', 'Save current session to...'); 	% Ask user to specify Excel file to save to
%                 if isequal(Filename,0) || isequal(Pathname,0)                                               
%                     return
%                 end
%                 Defaults.HistoryFile = fullfile(Pathname, Filename);                     	% Set full path of Excel file
%             end
%             [status,SheetNames] = xlsfinfo(Defaults.HistoryFile);                           % Get Excel sheet names
%             if ~isfield(Defaults,'DateSheet')
%                 [Selection,ok] = listdlg('ListString',SheetNames,...                        	% Ask user to select a sheet
%                                          'ListSize',[160 60],...
%                                          'SelectionMode', 'multiple',...
%                                          'PromptString','Select Excel sheet(s):');
%                 Defaults.ExcelSheet = Selection;
%             end
%             Data = [];
%             for s = 1:numel(Defaults.ExcelSheet)
%                 [num,txt,raw] =  xlsread(Defaults.HistoryFile,SheetNames{s},'','basic');  	% Read Excel file
%                 Data = [Data; num];
%             end
            Params = LoadSessionParams(Defaults.HistoryFile);
            Target = Params.Target;
            Electrode.CurrentDepth = Params.Depth;
            Session.Date = Params.Date;
            Session.ElectrodeID = Params.ElectrodeID;
            Session.GuideLength = Params.GuideLength;
            Session.Details = {Session.Subject,Session.Date,Session.ElectrodeID};
            ElectrodeIDIndx = find(strncmp(Params.ElectrodeID,Electrode.AllTypes, 2));
            set(Session.InputHandle(2), 'value',Params.DateIndex);
            set(Session.InputHandle(3), 'value',ElectrodeIDIndx);
            Button.CurrentValues = [Target(1),Target(2),0, 0, Electrode.CurrentDepth, Session.GuideLength];
            for i = 1:numel(Button.CurrentValues)
                set(Button.InputHandle(i),'String',num2str(Button.CurrentValues(i)));
            end
            Layer.M = DrawMRI(Target, Electrode);
            Electrode.GT = DrawGuidetube(Target, Electrode); 
            Electrode = DrawElectrode(Target, Electrode); 
            
        case 2  	%============================= SAVE current session
            if exist(Defaults.HistoryFile,'file')==0                                                        % If default Excel file doesntt exist...
              	[Filename, Pathname, Indx] = uiputfile({'.csv';'.xls'}, 'Save current session to...');  	% Ask user to specify file to save to
                if isequal(Filename,0) || isequal(Pathname,0)                                               
                    return
                end
                Defaults.HistoryFile = fullfile(Pathname, Filename);                                        % Set full path of Excel file
            end
  
            %========= WRITE DATA TO .XLS FILE
            if strcmpi(Defaults.HistoryFile(end-2:end), 'xls')
                if exist('readtable','file')~=0
                    T = readtable(Defaults.HistoryFile);
                    T.Date = datetime(T.Date,'ConvertFrom','excel');
                    Cells = {Session.Date, Target(1), Target(2), Electrode.CurrentDepth, Session.GuideLength, 0, Session.ElectrodeID};
                    T = [T; Cells];                                                                             % Append new data
                    writetable(T,Defaults.HistoryFile);
                else
                    try
                        [num,txt,raw] =  xlsread(Defaults.HistoryFile,1,'');     	% Read data from Excel file
                        Headers = txt{1,:};                                       	% Skip row containing column titles
                        for i = 2:size(raw,1)
                            raw{i,1} = raw{i,1}+datenum('30-Dec-1899');             % Convert Excel dates to Matlab dates
                        end
                        raw(end+1,:) = Cells;
                        [Success, Msg] = xlswrite(Defaults.HistoryFile, raw);         
                    catch
                        fprintf('Writing to %s failed! Try writing to .csv format instead.\n', Defaults.HistoryFile);
                        [Filename, Pathname, Indx] = uiputfile('.csv', 'Save current session to .csv file');  	% Ask user to specify file to save to
                        Defaults.HistoryFile = fullfile(Pathname, Filename);
                    end
                end
            end
            %========= WRITE DATA TO .CSV FILE
            if strcmpi(Defaults.HistoryFile(end-2:end), 'csv')                    
                formatSpec = '%{dd-MMM-yyyy}D%f%f%f%f%f%C';
                Cells = {Session.Date, Target(1), Target(2), Electrode.CurrentDepth, Session.GuideLength, 0, Session.ElectrodeID};
                if exist('readtable','file')~=0
                    T = readtable(Defaults.HistoryFile,'Delimiter',',','Format',formatSpec);
                    T = [T; Cells];                                                                         % Append new data
    %                 T = cell2table(T,'VariableNames',fieldnames(T));                                      % convert to table
                    T.Date.Format = 'dd-MMM-yyyy';                                              
                    writetable(T,Defaults.HistoryFile);                                                     % write table to .csv file
                else
                    T = csvread(Defaults.HistoryFile);
                    T = [T; Cells];
                    fid = fopen(Defaults.HistoryFile, 'wt');                                             	 % write table to .csv file
                    fprintf(fid, '%s, %s, %s, %s, %s, %s, %s\n', T{1,:});
                    for i = 2:size(T,1)
                        fprintf(fid, '%d, %d, %d, %f, %f, %d, %s\n', T{i,:});
                    end
                    fclose(fid);
                end
            end
          	h = msgbox('Session data has been saved.','Save successful!','modal');      % inform user that data was saved
            uiwait(h);                                                                  

        case 3      %============================= EDIT DEFAULTS
            Defaults = EN_Initialize;
            
            
        case 4      %============================= LOAD STRUCTURE VOLUMES
            StructureDir = fullfile(cd,'/Subjects/Layla/StructureVolumes');
            AllStructures = wildcardsearch(StructureDir, '*.nii');
            for S = 1:numel(AllStructures)
                [a,b,c] = fileparts(AllStructures{S});
                StructureNames{S} = b;
            end
          	[Selection,ok] = listdlg('ListString',StructureNames,'SelectionMode','multi','PromptString','Select structures:','ListSize',[300, 200]);
            if ok==0
                return;
            end
            H = waitbar(0,sprintf('Loading selected structure %d of %d...',S,numel(Selection)));
            Hh = get(findobj(H,'type','axes'),'title');
            for S = 1:numel(Selection)
                waitbar((S-1)/numel(Selection),H);
                set(Hh, 'string', sprintf('Loading selected structure %d of %d...',S,numel(Selection)));
            	StructNii(S) = load_nii(AllStructures{Selection(S)});
                VoxelDim(S,:) = StructNii(S).hdr.dime.pixdim(2:4);                     % Get voxel dimensions
                VolumeDim(S,:) = size(StructNii(S).img);                               % Get volume dimensions
            end
            close(H);
       
            %=============== Check volumes
            
            
            
            %=============== Add volumes
            OriginalLayers = numel(Layer.MRI);
            for S = 1:numel(Selection)
                n = S+OriginalLayers;
                Layer.MRI(n).img = double(StructNii(S).img);                                   	% Save image volume
             	Layer.MRI(n).AlphaMaskVolume = Layer.MRI(n).img;                                % Create alpha mask volume equal in size to atlas volume
                Layer.MRI(n).VoxelDim = StructNii(S).hdr.dime.pixdim(2:4);                     	% Get voxel size (mm)
                Layer.MRI(n).DimVox = size(StructNii(S).img);                                 	% Get full volume dimensions (voxels)
                Layer.MRI(n).DimMM = Layer.MRI(n).DimVox.*Layer.MRI(n).VoxelDim;                % Convert volume dim to mm
                Layer.MRI(n).OriginVox = StructNii(S).hdr.hist.originator(1:3);               	% Get origin coordinates (voxels)
                Layer.MRI(n).OriginMM = Layer.MRI(n).OriginVox.*Layer.MRI(n).VoxelDim;        	% Convert origin to mm
                
                Layer.MRI(n).LowerBoundsMM = [StructNii(S).hdr.hist.srow_x(4), StructNii(S).hdr.hist.srow_y(4), StructNii(S).hdr.hist.srow_z(4)];
                Layer.MRI(n).UpperBoundsMM = Layer.MRI(n).DimMM-abs(Layer.MRI(n).LowerBoundsMM);
                Layer.MRI(n).BoundsSagMM = [Layer.MRI(n).LowerBoundsMM(1), Layer.MRI(n).UpperBoundsMM(1)];   % Get bounds in sagital plane (mm)
                Layer.MRI(n).BoundsCorMM = [Layer.MRI(n).LowerBoundsMM(2), Layer.MRI(n).UpperBoundsMM(2)];   % Get bounds in coronal plane (mm)
                Layer.MRI(n).BoundsAxMM = [Layer.MRI(n).LowerBoundsMM(3), Layer.MRI(n).UpperBoundsMM(3)];    % Get bounds in axial plane (mm)

                
                
            end
            Layer.StructNames = [Layer.StructNames, StructureNames{Selection}];               	% Append new structures
            set(Layer.InputHandle(2), 'string', Layer.StructNames);
            Layer.Colors = [Layer.Colors; rand(numel(Selection),3)];
            Layer.Opacity = [Layer.Opacity, ones(1,numel(Selection))/2];
            Layer.Smoothing = [Layer.Smoothing, zeros(1,numel(Selection))];
            Layer.sigma = [Layer.sigma, zeros(1,numel(Selection))];
            


            
        case 5      %============================= CAPTURE figure as print-quality image
            ImFormat = 'png';
            FileName = sprintf('Fig_%s_%s.%s',Session.Subject,datestr(datenum(Session.Date,'dd-mmm-yyyy'),'yyyy-mm-dd'), ImFormat);
            DirName = fullfile(Session.RootDir,'Subjects',Session.Subject,'Renders');
            if ~exist(DirName, 'dir')
                mkdir(DirName);
            end
            FullFilename = fullfile(DirName,FileName);
            set(gcf,'InvertHardcopy','off');
            if Indx2 == 1       %========= Capture whole GUI window
                export_fig(FullFilename,['-',ImFormat],'-nocrop');
            
            elseif Indx2 == 2   %========= Copy MRI panel to new figure window
                NewFigH = figure('Color',Fig.Background,...             % Set the figure window background color
                              	'Renderer','OpenGL',...               	% Use OpenGL renderer
                                'OuterPosition', Fig.Rect);          	% position figure window to fit fullscreen;
                s(1) = copyobj(Fig.PlotHandle(4), NewFigH);
                set(s(1),'position',[0.05 0.1 0.4 0.8]);
                colormap gray;
                Session.Date
%                 title(sprintf('%s %s - hole = [%d, %d]', Session.Subject, Session.Date, Target(1), Target(2)),'units','normalized','position',[0,1.1],'fontsize',18);
                title(sprintf('%s %s - hole = [%d, %d]', Session.Subject, Session.Date, Target(1), Target(2)),'horizontalalignment','left','fontsize',18);
                s(2) = copyobj(Fig.PlotHandle(4), NewFigH);
                set(s(2),'position',[0.55 0.1 0.4 0.8]);
                set(gca,'zlim',[-20 40],'ylim',[-48 30]);
             	set(s,'clim',[0 1]);
                export_fig(FullFilename,['-',ImFormat],'-nocrop');
                close(NewFigH);
            end
            
        case 6      %============================= OPEN POST-SESSION STRUCTURAL MRI
            
            for d = 1:numel(Defaults.DateFormats)
                DateDir = datestr(datenum(Session.Date,'dd-mmm-yyyy'),Defaults.DateFormats{d});
                Session.MRIDataDir = fullfile(Session.MRIRootDir, Session.Subject, [DateDir,'*']);
                SessionDirs = dir(Session.MRIDataDir);
                if ~isempty(SessionDirs)
                    break;
                end
            end
            if isempty(SessionDirs)
                Message = sprintf('No structural MRI data found for %s on %s!', Session.Subject, Session.Date);
                h = msgbox(Message,'Error');
                return;
            else
                Session.MRIDataDir = fullfile(Session.MRIRootDir, Session.Subject, SessionDirs(1).name);
                [filename,pathname] = uigetfile({  '*.nii;*.img;*dcm','MRI formats';...
                                                    '*.jpg;*.png;*.bmp;*.tif','Image formats'}, 'Select MRI data to view', Session.MRIDataDir);
              	Session.MRIFilename = fullfile(pathname,filename);
                fprintf('MRI file selected: %s\n', Session.MRIFilename);
            end
            
        case 7      %============================ QUIT
            close all;
            clear all;
    
    end
end


%======================== ATLAS MENU CALLBACK =============================
function AtlasSelect(hObj, Event, Indx1, Indx2)
global Fig

switch Indx1
    case 1  %================================= 3D slice view option
        
        
    case 2  %================================= 3D surface view option
        Params3D = InitializeAtlasViewer3D;
        
        
    case 3  %================================= BrainMaps Option
        switch Indx2
            case 1  
                Template = '5';             % Axial
            case 2
                Template = '151';           % Coronal
            case 3
                Template = '6';             % Sagittal
        end
     	URL = sprintf('http://brainmaps.org/index.php?action=viewslides&datid=%s', Template);
        stat = web(URL, '-browser');
        
    case 4  %================================= Scalable Brain Atlas Option
    	switch Indx2
            case 1  
                Template = 'DB08';          % NeuroMaps
            case 2
                Template = 'PHT00';      	% Paxinos
            case 3
                Template = 'LVE00_on_F99'; 	% Carret
        end
        URL = sprintf('http://scalablebrainatlas.incf.org/main/coronal3d.php?template=%s&', Template);
        stat = web(URL, '-browser');
        
    case 5  %================================= PDF Option
        PDF = Fig.AtlasLabels{6}{Indx2};
%         system(sprintf('open(''%s'')', fullfile(Fig.AtlasPDFDir,PDF)));
        eval(sprintf('open(''%s'')', fullfile(Fig.AtlasPDFDir,PDF)));
end
end


%========================== DATA MENU CALLBACK ============================
function DataSelect(hObj, Event, Indx1, Indx2)
global Session Electrode Grid Defaults

switch Indx1
    case 1      %=========================== VIEW RAW DATA
        
        ScreenshotDir = '';
        AllScreenShots = dir(ScreenshotDir);
        
        
    case 2      %=========================== VIEW EXPERIMENTAL DATA

        for d = 1:numel(Defaults.DateFormats)
            DateDir = datestr(datenum(Session.Date,'dd-mmm-yyyy'),Defaults.DateFormats{d});
            Session.PhysioDataDir = fullfile(Defaults.ExpDir, [DateDir,'*']);
            SessionDirs = dir(Session.PhysioDataDir);
            if ~isempty(SessionDirs)
                break;
            end
        end
        if isempty(SessionDirs)
            Message = sprintf('No analysed data found for %s, contact # %d!', Session.Date, Electrode.CurrentSelected);
            h = msgbox(Message,'Error');
            return;
        else
            FileName = sprintf('%s-%s-%s-%s-neuResp-ch%d-*', Session.Subject, DateDir, SessionDirs(1).name(end), ExperimentName,Electrode.CurrentSelected);
            AllFiles = dir(fullfile(Session.PhysioRootDir, Session.Subject, SessionDirs(1).name, FileName));
            AllFiles = struct2cell(AllFiles);
            AllFiles(2:end,:) = [];
            [Selection,ok] = listdlg('ListString',AllFiles,'SelectionMode','multiple','PromptString','Select data to view:','ListSize',[300,150]);
            if ok == 1
                for f = 1:numel(Selection)
                    Img{f} = imread(fullfile(Session.PhysioRootDir, Session.Subject, SessionDirs(1).name, AllFiles{Selection(f)}));
                    figure;
                    Session.DataView(f) = imshow(Img{f}); 
                end
            end
        end

        
    case 3      %======================= VIEW GENERAL RECORDING HISTORY DATA
        GridHistHandle = GridHistory(Defaults.HistoryFile,Indx2, Defaults.GridID);

end
end