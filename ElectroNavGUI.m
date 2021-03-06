function h = ElectroNavGUI(SubjectID)

%============================== ElectroNavGUI.m ============================== 
% This function plots several 3D visualizations of electrode position 
% relative to the specified grid hole, guide tube, and estimated target depth. 
% Data can be saved and loaded, and various options are provided for
% visualization through the GUI.
%
% INPUTS:
%	Subject ID:     string containing animal name or ID number
%
% MATLAB REQUIREMENTS (INCLUDED):
% 	Graph Theory Toolbox:   http://www.mathworks.com/matlabcentral/fileexchange/5355-toolbox-graph
%   Nifti toolbox:          http://www.mathworks.us/matlabcentral/fileexchange/8797-tools-for-nifti-and-analyze-image
%
% MRI ATLAS REQUIREMENTS (OPTIONAL):
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
%   11/09/2015 - Updated for multiple electrode recordings
%     ___  ______  __   __
%    /   ||  __  \|  \ |  \    APM SUBFUNCTIONS
%   / /| || |__/ /|   \|   \   Aidan P. Murphy - murphyap@mail.nih.gov
%  / __  ||  ___/ | |\   |\ \  Section of Cognitive Neurophysiology and Imaging
% /_/  |_||_|     |_| \__| \_\ Laboratory of Neuropsychology, NIMH
%==========================================================================

% persistent Fig
clear -global
global Electrode Fig Grid Session Button Surface Brain Contact Defaults Layer

set(0,'DefaultLineLineSmoothing','on');
set(0,'DefaultPatchLineSmoothing','on');
[RootDir, mfile] = fileparts(mfilename('fullpath'));
addpath(genpath(RootDir));
Session.RootDir = RootDir;


%================== LOAD SUBJECT PARAMETERS & DIRECTORIES =================
[t, CompName] = system('hostname');
DefaultParametersFile = sprintf('ParamsFile_%s.mat', CompName(1:end-1));
if exist('SubjectID','var')
    Defaults = EN_Initialize(DefaultParametersFile, SubjectID);
else
    Defaults = EN_Initialize(DefaultParametersFile);
end
LoadingHandle           = EN_About(1);              % Open 'Loading...' window
Defaults.MRIRootDir     = [];
Defaults.DateFormats    = {'yyyymmdd','ddmmyy'};   
Session.Date            = date;
Session.Subject         = Defaults.SubjectID;


%=============== CALCULATE ROTATION MATRICES
if exist(Defaults.Xform,'file')
    if strcmp(Defaults.Xform(end-2:end),'mat')
        load(Defaults.Xform);
        Brain.Xform         = T;
        Brain.ChamberOrigin =  T*[0 0 0 1]';
    elseif strcmp(Defaults.Xform(end-4:end),'xform')
        fileID = fopen(Defaults.Xform);                                     % Open Xform file
        Defaults.Xform = cell2mat(textscan(fileID,'%f %f %f %f\n'));       	% Read Xform to matrix
        Defaults.InverseXform = inv(Defaults.Xform);                       	% Calculate inverse transform matrix
        fclose(fileID);                                                 	% Close xform file
        Brain.Xform         = Defaults.Xform;                                       
        Brain.ChamberOrigin = Brain.Xform*[0 0 0 1]';                       % Get grid origin (translation)
    end
end
    

%=================== SET GRID AND ELECTRODE SPECIFICATIONS ================
Grid = ENT_GetGridParams(Defaults.GridID);                                  % Get grid parameters based on grid ID
ElectrodeNumbers      	= 1;                                                % Set default number of electrodes used
for e = ElectrodeNumbers                                                    % For each electrode...
  	[Electrode.Selected]            = deal(e);                          	% Selected electrode defaults to 1 
    Electrode(e).ID                 = 'PLX24_A';                            
    Electrode(e).Target           	= [0,0];                                % Default target is centre grid hole
    Electrode(e).Numbers            = ElectrodeNumbers;                         
    Electrode(e).QualityColorMap	= [0 0 0; 1 0 0; 1 0.5 0; 1 1 0; 0 1 0];
    Electrode                       = ENT_GetElectrodeParams(Electrode);   	% Get electrode parameters based on electrode ID
    Electrode(e).AllTypes           = sortrows(ENT_GetElectrodeParams');   	% Get list of all electrode types 
 	Electrode(e).StartDepth         = 0;                                    % Manual start depth (relative to grid base)
    Electrode(e).MicrodriveDepth    = 0;                                    % Maicrodrive readout depth (relative to start depth)
    Electrode(e).CurrentDepth       = 0;                                    % Total depth (mm)
    Electrode(e).IDColors         	= {'r','b','m','g','c'};              	% Electrode ID color
    Electrode(e).GuideLength        = 27;                                   % Default guidetube length (mm)
end
[Electrode.Selected]           = deal(1);  


%=============== LOAD RECORDING HISTORY FROM SPREADSHEET
if exist(Defaults.HistoryFile, 'file') ==2                             	% If recording history file was found...   
    Hist = ENT_LoadSessionParams(Defaults.HistoryFile, 'All'); 
    Session.DateStrings = cell2mat({Hist.DateString}');
else
    Session.DateStrings = [];
end
Session.DateStrings(end+1,:) = date;                              	% Add todays date to end of list
Session.CurrentDate = size(Session.DateStrings,1);                  % Default to todays date   


%============== SET DEFAULT 3D SURFACE PARAMS
Brain.Specular          = 0.2;
Brain.Ambient           = 0.2;
Brain.Diffuse           = 0.6;
Brain.Alpha             = 0.5;
Brain.RGB               = [0.7 0.6 0.6];
Brain.DefaultView       = [-120 20];                                  
Brain.SurfaceColors     = [1 0 0;0 1 0;0 0 1;1 1 0;1 0 1;0 1 1];
Brain.PlanesAlpha       = 0.4;                                                                     
Brain.PlanesOn          = 1;                                         

%========================= LOAD VOLUMES ===================================
Layer.Filenames       	= {Defaults.MRI, Defaults.Atlas};
Layer.Names             = {'Native','Atlas'};       	
Layer.Colormap          = [];                                        
Layer.ColormapOrder     = {gray; jet; hot; cool};                   % Different colormap for each layer
Layer.CurrentSliceView  = 1;
Layer.CurrentStructure  = 1;
Layer.Opacity           = [1, 0.5,0.5,1];                         	% Set default alpha transparency for each layer 
Layer.Colors            = [0.5,0.5,0.5; 1 0 0; 0 1 0; 0 0 1];     	% Set default colors for each layer (RGB)
Layer.Smoothing       	= [0, 0.5, 1];                              % Set default Gaussian kernel for each layer (mm)
Layer.On                = [1 0];                                    % Set default layer visibility 
Layer.hsize             = [5 5];                                   	% Size of Gaussian smoothing kernel
Layer.sigma             = zeros(1,numel(Layer.Names));           	% default sd of Gaussian (mm)
Layer.SigmaMax          = 5;                                     	% maximum sd (mm)
Layer.SigmaMin          = 0;                                     	% minimum sd (mm)
Layer.IntensityRange    = [0 255]; 
Layer.ZoomOn            = 0;                                     	% zoom defaults to off
Layer.ZoomLevel         = 15;                                   	% space in mm to include around contacts when zoomed in

for n = 1:numel(Layer.Filenames)
    nii = load_nii(Layer.Filenames{n});
    if n == 1
        nii.img(nii.img>10000) = 10000;
    end
    Layer.MRI(n).img        = double(nii.img);                                       	% Save image volume
    Layer.MRI(n).VoxelDim   = nii.hdr.dime.pixdim(2:4);                                 % Get voxel size (mm)
    Layer.MRI(n).DimVox     = size(nii.img);                                            % Get full volume dimensions (voxels)
    Layer.MRI(n).DimMM      = Layer.MRI(n).DimVox.*Layer.MRI(n).VoxelDim;              	% Convert volume dim to mm
    Layer.MRI(n).OriginVox  = round(nii.hdr.hist.originator(1:3));                  	% Get origin coordinates (voxels)
    Layer.MRI(n).OriginMM   = Layer.MRI(n).OriginVox.*Layer.MRI(n).VoxelDim;        	% Convert origin to mm
    if nii.hdr.hist.sform_code > 0                                                      % Use S-form?
        Layer.MRI(n).Sform = [nii.hdr.hist.srow_x; nii.hdr.hist.srow_y; nii.hdr.hist.srow_z];
        Layer.MRI(n).Sform(4,:) = [0 0 0 1];
    end
    if nii.hdr.hist.qform_code > 0                                                      % Use Q-form?
        Layer.MRI(n).Rmat = Quarternion2Rotation(nii.hdr.hist.quatern_b, nii.hdr.hist.quatern_c, nii.hdr.hist.quatern_d);
        Layer.MRI(n).Tmat = [nii.hdr.hist.qoffset_x, nii.hdr.hist.qoffset_y, nii.hdr.hist.qoffset_z];
    end
  	Layer.MRI(n).LowerBoundsMM  = [nii.hdr.hist.srow_x(4), nii.hdr.hist.srow_y(4), nii.hdr.hist.srow_z(4)];
    Layer.MRI(n).UpperBoundsMM  = Layer.MRI(n).DimMM-abs(Layer.MRI(n).LowerBoundsMM);
    Layer.MRI(n).BoundsSagMM    = [Layer.MRI(n).LowerBoundsMM(1), Layer.MRI(n).UpperBoundsMM(1)];   % Get bounds in sagital plane (mm)
    Layer.MRI(n).BoundsCorMM    = [Layer.MRI(n).LowerBoundsMM(2), Layer.MRI(n).UpperBoundsMM(2)];   % Get bounds in coronal plane (mm)
    Layer.MRI(n).BoundsAxMM     = [Layer.MRI(n).LowerBoundsMM(3), Layer.MRI(n).UpperBoundsMM(3)];    % Get bounds in axial plane (mm)

    Layer.Colormap = [Layer.Colormap; Layer.ColormapOrder{n}]; 
    close gcf;
    if n > 1
        Layer.MRI(n).AlphaMaskVolume = zeros(size(nii.img));                        % Create alpha mask volume equal in size to atlas volume
        Layer.MRI(n).AlphaMaskVolume(nii.img > 0) = 1;                              % For all atlas voxels > 0, mask volume voxels = 1
        Layer.MRI(n).img(nii.img>1000) = Layer.MRI(n).img(nii.img>1000)-1000;       % Make both hemispheres of atlas volume equal indices
    end
    Layer.MRI(n).MRImin = min(min(min(Layer.MRI(n).img)));                                       % Scale voxel intensities to range 0-1  
    Layer.MRI(n).MRImax = max(max(max(Layer.MRI(n).img)));
 	if n == 1
        Layer.MRI(n).img = ((Layer.MRI(n).img-Layer.MRI(n).MRImin)/(Layer.MRI(n).MRImax-Layer.MRI(n).MRImin))+n-1;
        Layer.MRI(n).img = Layer.MRI(n).img-0.0001;
    end
    Layer.MRI(n).SelectedStructIndx = 0;
    Layer.MRI(n).SelectedXYZ = [];
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
     	Surface.StructVTKs = wildcardsearch(Defaults.VTKdir,'pulvinar.vtk');
        Surface.StructFolder = Defaults.VTKdir;
       	Surface.Xlim = [-32 32];
        Surface.Ylim = [-50 30];
        Surface.Zlim = [-25 50];
    case 'Saleem-Logothetis'
        Surface.VTKfile = 'Niftii/McLaren/McLaren_surface.vtk';
        Surface.Xlim = [-32 32];
        Surface.Ylim = [-30 60];
        Surface.Zlim = [-10 50];
end 



%% =========================== FIGURE SETTINGS ==============================
Fig.Background      = [0.75 0.75 0.75];                   	% Set figure window background color
Fig.AxesBkgColor    = [0.75 0.75 0.75];                   	% Set axes background color 
Fig.FontSize        = 12;                                 	% Set default font size for axis labels etc
Fig.UIFontsize      = 12;                                        
Fig.PlotSpacing    	= 50;                                	% Set spacing between plots (pixels)
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
Fig.UIControlDim    = [220, 180];                         	% Set dimensions of GUI control boxes (pixels)
Fig.Az              = 20;                                 	% Set azimuth angle (deg) for 3D view
Fig.El              = 40;                                 	% Set elevation angle (deg) for 3D view
Fig.Position(1,:)   = [0.15,0.75,0.25,0.25];            	% Set axis positions (normalized units)
Fig.Position(2,:)   = [0.15,0.4,0.25,0.25];
Fig.Position(3,:)   = [0.15,0.05,0.25,0.25];
Fig.Position(4,:)   = [0.3,0.1,0.8,0.8];
Fig.Position(5,:)   = [0.90,0.05,0.10,0.9];

                
%============================ CREATE MENUS ==============================

%======================= FILE TAB
Fig.FileMenuH{1} = uimenu(Fig.Handle,'Label','File'); 
Fig.FileLabels = {'Load session','Save session','Edit defaults','Export figure','View session MRI','Quit'};
Fig.ExportLabels = {'Full window','MRI panel'};
Fig.FileAccelerators = {'L','S','','E','','Q'};
for n = 1:numel(Fig.FileLabels)
    Fig.FileMenuH{2}(n) = uimenu(Fig.FileMenuH{1},...
                                'Label',Fig.FileLabels{n},...
                                'Callback',{@FileSelect,n,0},...
                                'Accelerator', Fig.FileAccelerators{n},...
                                'Enable','on');
end
set(Fig.FileMenuH{2}(n), 'Separator','on');
for m = 1:numel(Fig.ExportLabels)
    Fig.FileMenuH{3}(m) = uimenu(Fig.FileMenuH{2}(4),...                      % Create sub-options
                               'Label',Fig.ExportLabels{m},...
                               'Callback',{@FileSelect,4,m},...
                               'Enable','on');  
end

%======================= EDIT TAB
Fig.EditMenuH{1} = uimenu(Fig.Handle,'Label','Edit'); 
Fig.EditLabels = {'Load volumes','Remove volumes','Add electrode','Delete electrode','Adjust transform','Adjust MRI'};
Fig.EditAccelerators = {'','','','','',''};
for n = 1:numel(Fig.EditLabels)
    Fig.EditMenuH{2}(n) = uimenu(Fig.EditMenuH{1},...
                                'Label',Fig.EditLabels{n},...
                                'Callback',{@EditSelect,n},...
                                'Accelerator', Fig.EditAccelerators{n},...
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
Fig.DataLabels{4} = {'Frequency by hole','Recency by hole','Plot 3D'};

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
% set(0, 'currentfigure', Fig.Handle);
set(Fig.Handle,'units','normalized');
Fig.PlotHandle(1) = axes('units','normalized');                             % Axes 1 displays 2D grid view from above
set(Fig.PlotHandle(1),'position',Fig.Position(1,:));
Grid = Draw2DGrid(Grid,[0 0 0]);

Fig.PlotHandle(2) = axes('position',Fig.Position(2,:));                   	% Axes 2 displays axial whole brain view (3D)
Brain = DrawBrain3D(Brain, Electrode, Grid);
view(0,90);
camlight('infinite');
        
Fig.PlotHandle(3) = axes('position',Fig.Position(3,:));                   	% Axes 3 displays coronal whole brain view (3D)
Brain = DrawBrain3D(Brain, Electrode, Grid);
view(0,0);
camlight('infinite');

Fig.PlotHandle(4) = axes('position',Fig.Position(4,:));                  	% Axes 4 displays electrode MRI sagittal view
Layer.M = DrawMRI(Electrode);
for e = 1:numel(Electrode)
    [Electrode.Selected] = deal(e);
    Electrode(e).GT = DrawGuidetube(Electrode);   
    Electrode = DrawElectrode(Electrode);   
end

Fig.PlotHandle(5) = axes('position',Fig.Position(5,:));                  	% Axes 5 displays electrode contact selection
Electrode = DrawContacts(Electrode);

set(Fig.PlotHandle, 'fontsize', Fig.FontSize);



%% ======================= INITIALIZE UI CONTROLS =========================
Logo= imread(fullfile('Documentation','ElectroNavLogo1.png'),'BackgroundColor',Fig.Background);
LogoAx = axes('box','off','units','pixels','position', [20, Fig.Rect(4)-180, Fig.UIControlDim(1), 42],'color',Fig.Background);
image(Logo);
axis equal off

Session.BoxPos  = [20 Fig.Rect(4)-350 Fig.UIControlDim(1), 140];
Button.BoxPos   = [20 Session.BoxPos(2)-170 Fig.UIControlDim(1), 160];
Contact.BoxPos  = [20 Button.BoxPos(2)-170 Fig.UIControlDim(1),160];
Layer.BoxPos    = [20 Contact.BoxPos(2)-180 Fig.UIControlDim(1),170];
Surface.BoxPos  = [20 Layer.BoxPos(2)-10 Fig.UIControlDim, 110];

%=============== SESSION DETAILS
Session.InputDim    = [100 20];
Session.Labels      = {'Subject ID','Date','Electrode number','Electrode type','No. channels'};
Session.Style       = {'Text','popup','popup','popup','edit'};
Session.List        = {Session.Subject, Session.DateStrings, Electrode(Electrode(1).Selected).Numbers, Electrode(Electrode(1).Selected).AllTypes, 24};
Session.UIhandle    = uipanel('Title','Session details','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','pixels','Position',Session.BoxPos);
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
set(Session.InputHandle(2),'value', Session.CurrentDate);
set(Session.InputHandle(3),'value', Electrode(1).Selected);
set(Session.InputHandle(4),'value', find(~cellfun(@isempty, strfind(Electrode(Electrode(1).Selected).AllTypes, Electrode(Electrode(1).Selected).Brand))));

%=============== ELECTRODE POSITION
Button.InputDim         = [100 20];
Button.Labels           = {'M-L','A-P','Manual depth','Microdrive depth','Total depth','Guide length'};
Button.CurrentValues    = {Electrode(Electrode(1).Selected).Target(1),Electrode(Electrode(1).Selected).Target(2),Electrode(Electrode(1).Selected).StartDepth, Electrode(Electrode(1).Selected).MicrodriveDepth, Electrode(Electrode(1).Selected).CurrentDepth, Electrode(Electrode(1).Selected).GuideLength};
Button.Units            = {'holes','holes','mm','mm','mm','mm'};
Button.UIhandle     	= uipanel('Title','Electrode position','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','pixels','Position',Button.BoxPos);
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
Contact.InputDim    = [100 20];
Contact.Labels      = {'Contact #',sprintf('Spike quality (0-%d)', size(Electrode(Electrode(1).Selected).QualityColorMap,1)-1),'Zoom level (mm)','Zoom to contacts','Go to slice'};
Contact.Input       = {num2str(Electrode(Electrode(1).Selected).CurrentSelected), num2str(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected)),num2str(Layer.ZoomLevel)};
Contact.Style       = {'Text', 'Text', 'Text','ToggleButton','PushButton'};
Contact.UIhandle    = uipanel('Title','Contact selection','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','pixels','Position',Contact.BoxPos);
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
Layer.ButtonDim     = [100 20];
Layer.UIhandle      = uipanel('Title','Layer controls','FontSize', Fig.UIFontsize,'Units','pixels','Position',Layer.BoxPos);
Layer.StructNames   = {'Native T1', 'Atlas'};
Layer.LabelStrings  = {'Main view','Current structure','Color','Opacity','Smoothing',''};
Layer.InputType     = {'popupmenu','popupmenu','PushButton','slider','slider', 'checkbox'};
Layer.InputStrings  = {{'Sagittal','Coronal','Axial'}, Layer.StructNames, [], [], [], 'Outline?'};
Layer.InputValue    = {Layer.CurrentSliceView, Layer.CurrentStructure, [], Layer.Opacity(Layer.CurrentStructure), Layer.Smoothing(Layer.CurrentStructure), 0};
Layer.ButtonPos     = [repmat(10,[numel(Layer.LabelStrings),1]), [0:20:((numel(Layer.LabelStrings)-1)*20)]'+30];
Layer.ButtonPos     = Layer.ButtonPos(end:-1:1,:);
for i = 1:numel(Layer.LabelStrings)
    Layer.LabelHandle(i) = uicontrol('Style','text', 'string', Layer.LabelStrings{i},'HorizontalAlignment','Left', 'pos', [Layer.ButtonPos(i,:), Layer.ButtonDim],'parent',Layer.UIhandle);
    Layer.InputHandle(i) = uicontrol('Style',Layer.InputType{i},'String',Layer.InputStrings{i},'value',Layer.InputValue{i}, 'pos',[Layer.ButtonPos(i,:)+[Layer.ButtonDim(1), 0], Layer.ButtonDim],'parent',Layer.UIhandle,'Callback',{@LayerView,i}); 
end
set([Layer.UIhandle, Layer.LabelHandle], 'BackgroundColor',Fig.Background);
set(Layer.InputHandle(3), 'BackgroundColor', Layer.Colors(Layer.CurrentStructure, :));
set(Layer.InputHandle(6), 'BackgroundColor',Fig.Background);


%============= 
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
    Grid.Object     = [];
    Grid.Perm(1) = FillCircle(Position([1,2]),Grid.OuterRadius,100,'y');
    hold on;
  	Grid.Perm(2) = plot([0 0],[-Grid.OuterRadius,Grid.OuterRadius],'-k');
    Grid.Perm(3) = plot([-Grid.OuterRadius,Grid.OuterRadius],[0 0],'-k');
    try                                                                     
        set(Grid.Perm,'hittest','off','PickableParts','none');       % 'PickableParts' line property from R2014a
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
    uistack(Grid.Perm(1), 'bottom');
end


%=========================== DRAW GUIDE TUBE ==============================
function GT = DrawGuidetube(Electrode)
    global Fig Grid Brain
    if isfield(Electrode,'GT')
        if ~isempty(Electrode(Electrode(1).Selected).GT)
            for m = 1:numel(Electrode(Electrode(1).Selected).GT)
                if ishandle(Electrode(Electrode(1).Selected).GT(m))
                    delete(Electrode(Electrode(1).Selected).GT(m));
                end
            end
            Electrode(Electrode(1).Selected).GT=[];
        end
    end
    GT = [];
    for h = 2:4
     	set(Fig.Handle, 'currentaxes', Fig.PlotHandle(h));
        
        %========== draw guide tube top
        [X,Y,Z] = cylinder(Grid.HoleDiameter,100);
        X = X+Electrode(Electrode(1).Selected).Target(1);
        Y = Y+Electrode(Electrode(1).Selected).Target(2);
        Z = (Z*Grid.GuideTop)+Grid.Width;
    	fvc = surf2patch(X,Y,Z);
        fvc.vertices = ApplyTform(fvc.vertices);
        GT(end+1) = patch('Faces',fvc.faces,'Vertices',fvc.vertices,'FaceColor',Electrode(Electrode(1).Selected).GuideColor,'EdgeColor','none');
        
        %========= Draw guide tube shaft
        [X,Y,Z] = cylinder(Grid.HoleDiameter/2,100);
        X = X+Electrode(Electrode(1).Selected).Target(1);
        Y = Y+Electrode(Electrode(1).Selected).Target(2);
        Z = (Z*-Electrode(Electrode(1).Selected).GuideLength)+Grid.Width;
        fvc = surf2patch(X,Y,Z);
        fvc.vertices = ApplyTform(fvc.vertices);
        GT(end+1) = patch('Faces',fvc.faces,'Vertices',fvc.vertices,'FaceColor',Electrode(Electrode(1).Selected).GuideColor,'EdgeColor','none');
        alpha(GT, Electrode(Electrode(1).Selected).GuideAlpha);
    end

end

%=========================== DRAW ELECTRODE ===============================
function Electrode = DrawElectrode(Electrode)
    global Fig Grid Brain Layer
    
    %========================= 2D grid view    
    if isfield(Electrode,'E') && ~isempty(Electrode(Electrode(1).Selected).E) && ishandle(Electrode(Electrode(1).Selected).E{1}(1))
        CurrXData = get(Electrode(Electrode(1).Selected).E{1}(1), 'Xdata');
        CurrYData = get(Electrode(Electrode(1).Selected).E{1}(1), 'Ydata');
        NewXData = CurrXData + diff([mean(CurrXData), Electrode(Electrode(1).Selected).Target(1)]);
        NewYData = CurrYData + diff([mean(CurrYData), Electrode(Electrode(1).Selected).Target(2)]);
        set(Electrode(Electrode(1).Selected).E{1}(1), 'Xdata', NewXData, 'Ydata', NewYData);
        set(Electrode(Electrode(1).Selected).E{1}(2), 'Xdata', repmat(Electrode(Electrode(1).Selected).Target(1),[1,2]));
        set(Electrode(Electrode(1).Selected).E{1}(3), 'Ydata', repmat(Electrode(Electrode(1).Selected).Target(2),[1,2]));
    elseif ~isfield(Electrode,'E') || isempty(Electrode(Electrode(1).Selected).E) || ~ishandle(Electrode(Electrode(1).Selected).E{1}(1))
        set(Fig.Handle, 'currentaxes', Fig.PlotHandle(1));
        Electrode(Electrode(1).Selected).E{1}(1) = FillCircle(Electrode(Electrode(1).Selected).Target([1,2]),Grid.HoleDiameter/2,100, Electrode(1).IDColors{Electrode(1).Selected});
        Electrode(Electrode(1).Selected).E{1}(2) = plot(repmat(Electrode(Electrode(1).Selected).Target(1),[1,2]),[-Grid.OuterRadius,Grid.OuterRadius],['-',Electrode(1).IDColors{Electrode(1).Selected}]);
        Electrode(Electrode(1).Selected).E{1}(3) = plot([-Grid.OuterRadius,Grid.OuterRadius],repmat(Electrode(Electrode(1).Selected).Target(2),[1,2]),['-',Electrode(1).IDColors{Electrode(1).Selected}]);
        try
            set(Electrode(Electrode(1).Selected).E{1}([2,3]),'hittest','off','PickableParts','none');
        end
	end
            
    %========================= 3D views
    [X,Y,Z] = cylinder(Electrode(Electrode(1).Selected).Diameter/2,100);           % Electrode shaft
    X = X+Electrode(Electrode(1).Selected).Target(1);
    Y = Y+Electrode(Electrode(1).Selected).Target(2);
    Z1 = (Z*(Electrode(Electrode(1).Selected).Length-Electrode(Electrode(1).Selected).TipLength))-Electrode(Electrode(1).Selected).CurrentDepth+Electrode(Electrode(1).Selected).TipLength;
    fvc1 = surf2patch(X,Y,Z1);
    fvc1.vertices = ApplyTform(fvc1.vertices);
    
    [X2,Y2,Z2] = cylinder([0 Electrode(Electrode(1).Selected).Diameter/2]);        % Electrode tip
    X2 = X2+Electrode(Electrode(1).Selected).Target(1);
    Y2 = Y2+Electrode(Electrode(1).Selected).Target(2);
    Z2 = (Z2*Electrode(Electrode(1).Selected).TipLength)-Electrode(Electrode(1).Selected).CurrentDepth;
    fvc2 = surf2patch(X2,Y2,Z2);
    fvc2.vertices = ApplyTform(fvc2.vertices);
    
    [X3,Y3,Z3] = cylinder(Electrode(Electrode(1).Selected).Diameter*0.55,100);     % Electrode contacts
    X3 = X3+Electrode(Electrode(1).Selected).Target(1);
    Y3 = Y3+Electrode(Electrode(1).Selected).Target(2);
        
    %=========== FOR EACH SLICE VIEW AXES...
    for fh = 2:4
        if numel(Electrode(Electrode(1).Selected).E)>=fh
            set(Electrode(Electrode(1).Selected).E{fh}(1),'Vertices',fvc1.vertices);
            set(Electrode(Electrode(1).Selected).E{fh}(2),'Vertices',fvc2.vertices);
        else
            set(Fig.Handle, 'currentaxes', Fig.PlotHandle(fh));
            Electrode(Electrode(1).Selected).E{fh}(1) = patch('Faces',fvc1.faces,'Vertices',fvc1.vertices,'FaceColor',Electrode(Electrode(1).Selected).MRIColor,'EdgeColor','none');
            Electrode(Electrode(1).Selected).E{fh}(2) = patch('Faces',fvc2.faces,'Vertices',fvc2.vertices,'FaceColor',Electrode(Electrode(1).Selected).MRIColor,'EdgeColor','none');
        end
        
        %=========== DRAW CONTACTS IN MAIN SLICE VIEW
        if fh == 4
            CurrentHandles = find(isgraphics2(Electrode(Electrode(1).Selected).E{4}));                      % Find valid graphics handles
            NoCurrentContacts = numel(CurrentHandles)-2;                                                    % How many contacts currently exist?
            for c = 1:max([Electrode(Electrode(1).Selected).ContactNumber, NoCurrentContacts])              % Loop through max number
                Z3 = (Z*Electrode(Electrode(1).Selected).ContactDiameter)-Electrode(Electrode(1).Selected).CurrentDepth+Electrode(Electrode(1).Selected).TipLength+(c-1)*Electrode(Electrode(1).Selected).ContactSpacing;
                [xa ya za] = ApplyTform(X3(1,:),Y3(1,:),Z3(1,:));
                [xb yb zb] = ApplyTform(X3(2,:),Y3(2,:),Z3(2,:));
                if c <= NoCurrentContacts && c <= Electrode(Electrode(1).Selected).ContactNumber            % 1) Contact # already exists: move it
                    set(Electrode(Electrode(1).Selected).E{fh}(2+c), 'xdata', [xa; xb], 'ydata', [ya;yb], 'zdata', [za;zb]);
                elseif c > NoCurrentContacts && c <= Electrode(Electrode(1).Selected).ContactNumber         % 2) Contact # doesn't exist: create it
                    Electrode(Electrode(1).Selected).E{fh}(2+c) = mesh([xa; xb], [ya;yb], [za;zb],'FaceColor',Electrode(Electrode(1).Selected).ContactColor,'EdgeColor','none');
                    hold on;
                elseif c > Electrode(Electrode(1).Selected).ContactNumber && c <= NoCurrentContacts         % Contact numbers > requested number: delete it
                	delete(Electrode(Electrode(1).Selected).E{fh}(2+c));
                end
            end
%          	drawnow;
        end

    end
    Electrode = DrawCurrentContact(Electrode);
    
    %========================= Plot crosshair planes in 3D view
    if Brain.PlanesOn == 1
        set(Fig.Handle, 'currentaxes', Fig.PlotHandle(2));
        Xlim = get(gca,'Xlim');
        Ylim = get(gca,'Ylim');
        Zlim = get(gca,'Zlim');     
        X = Electrode(Electrode(1).Selected).Target(1);
        Y = Electrode(Electrode(1).Selected).Target(2);
        Z = -Electrode(Electrode(1).Selected).CurrentDepth+Electrode(Electrode(1).Selected).TipLength+((Electrode(Electrode(1).Selected).CurrentSelected-1)*Electrode(Electrode(1).Selected).ContactSpacing);
        [X, Y, Z] = ApplyTform(X,Y,Z);
        if numel(Electrode(Electrode(1).Selected).E)>=5
            set(Electrode(Electrode(1).Selected).E{5}([1,3]),'Xdata', repmat(X,[1,4]), 'Ydata', [Ylim, Ylim([2,1])], 'Zdata', [Zlim(1),Zlim(1),Zlim(2),Zlim(2)]);
            set(Electrode(Electrode(1).Selected).E{5}(2),'Xdata', [Xlim, Xlim([2,1])], 'Ydata', repmat(Y,[1,4]), 'Zdata', [Zlim(1),Zlim(1),Zlim(2),Zlim(2)]);
            set(Electrode(Electrode(1).Selected).E{5}(4),'Xdata', [Xlim, Xlim([2,1])], 'Ydata', [Ylim(1),Ylim(1),Ylim(2),Ylim(2)], 'Zdata', repmat(Z,[1,4]));
        else
            Electrode(Electrode(1).Selected).E{5}(1) = patch(repmat(X,[1,4]), [Ylim, Ylim([2,1])], [Zlim(1),Zlim(1),Zlim(2),Zlim(2)],Electrode(1).IDColors{Electrode(1).Selected});
            Electrode(Electrode(1).Selected).E{5}(2) = patch([Xlim, Xlim([2,1])], repmat(Y,[1,4]), [Zlim(1),Zlim(1),Zlim(2),Zlim(2)],Electrode(1).IDColors{Electrode(1).Selected});
            set(Fig.Handle, 'currentaxes', Fig.PlotHandle(3));
            Electrode(Electrode(1).Selected).E{5}(3) = patch(repmat(X,[1,4]), [Ylim, Ylim([2,1])], [Zlim(1),Zlim(1),Zlim(2),Zlim(2)],Electrode(1).IDColors{Electrode(1).Selected});
            Electrode(Electrode(1).Selected).E{5}(4) = patch([Xlim, Xlim([2,1])], [Ylim(1),Ylim(1),Ylim(2),Ylim(2)], repmat(Z,[1,4]),Electrode(1).IDColors{Electrode(1).Selected});
            set(Electrode(Electrode(1).Selected).E{5},'FaceAlpha',Brain.PlanesAlpha);
            set(Electrode(Electrode(1).Selected).E{5},'Facecolor',Electrode(1).IDColors{Electrode(1).Selected});
            set(Electrode(Electrode(1).Selected).E{5},'EdgeColor',Electrode(1).IDColors{Electrode(1).Selected});
        end
    end
    
    %============ Set axis limits for main slice view
    if Layer.ZoomOn==1
     	Contacts = find(isgraphics2(Electrode(Electrode(1).Selected).E{4}));
        ZoomedXlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'xdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'xdata'),2))]);
        ZoomedYlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'ydata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'ydata'),2))]);
        ZoomedZlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'zdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'zdata'),2))]);
        set(Fig.PlotHandle(4), 'xlim', ZoomedXlims+[-Layer.ZoomLevel, Layer.ZoomLevel],'ylim', ZoomedYlims+[-Layer.ZoomLevel, Layer.ZoomLevel], 'zlim', ZoomedZlims+[-Layer.ZoomLevel, Layer.ZoomLevel]);

    elseif Layer.ZoomOn==0                                     %====== Zoom OUT
        set(Fig.PlotHandle(4),'xlim', Layer.MRI(1).BoundsSagMM);
        set(Fig.PlotHandle(4),'ylim', Layer.MRI(1).BoundsCorMM);
        set(Fig.PlotHandle(4),'zlim', Layer.MRI(1).BoundsAxMM);
    end
end


 %================ PLOT CROSSHAIRS ON MRI AT CURRENT CONTACT ==============
function Electrode = DrawCurrentContact(Electrode)
	global Fig Grid MRI Brain Atlas Layer
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(4));       	% Select axes #4 to display sagittal MRI slice
    X = Electrode(Electrode(1).Selected).Target(1);
    Y = Electrode(Electrode(1).Selected).Target(2);
    if Electrode(Electrode(1).Selected).CurrentSelected > 0
        Z = -Electrode(Electrode(1).Selected).CurrentDepth+Electrode(Electrode(1).Selected).TipLength+(Electrode(Electrode(1).Selected).CurrentSelected-1)*Electrode(Electrode(1).Selected).ContactSpacing;
    else 
        Z = -Electrode(Electrode(1).Selected).CurrentDepth;
    end
    [X, Y, Z] = ApplyTform(X,Y,Z);
    [CurrXpos,CurrYpos,CurrZpos] = deal(X,Y,Z);
    Electrode(Electrode(1).Selected).Contact.CurrPos = [CurrXpos,CurrYpos,CurrZpos];
    if isfield(Electrode,'XhairHandle') && ~isempty(Electrode(Electrode(1).Selected).XhairHandle)    	% Check whether a handle to crosshairs exists
        if ishandle(Electrode(Electrode(1).Selected).XhairHandle(1))                        
            set(Electrode(Electrode(1).Selected).XhairHandle(1),'xdata', [CurrXpos,CurrXpos], 'ydata', [CurrYpos,CurrYpos]);
            set(Electrode(Electrode(1).Selected).XhairHandle(2),'xdata', [CurrXpos,CurrXpos], 'zdata', [CurrZpos,CurrZpos]);
            set(Electrode(Electrode(1).Selected).XhairHandle(3),'ydata', [CurrYpos,CurrYpos], 'zdata', [CurrZpos,CurrZpos]);
        end
    else
        Electrode(Electrode(1).Selected).XhairHandle(1) = plot3([CurrXpos,CurrXpos],[CurrYpos,CurrYpos],Layer.MRI(1).BoundsAxMM,['-',Electrode(1).IDColors{Electrode(1).Selected}]);  
        hold on;
        Electrode(Electrode(1).Selected).XhairHandle(2) = plot3([CurrXpos,CurrXpos],Layer.MRI(1).BoundsCorMM,[CurrZpos,CurrZpos],['-',Electrode(1).IDColors{Electrode(1).Selected}]);
        Electrode(Electrode(1).Selected).XhairHandle(3) = plot3(Layer.MRI(1).BoundsSagMM,[CurrYpos,CurrYpos],[CurrZpos,CurrZpos],['-',Electrode(1).IDColors{Electrode(1).Selected}]);
    end 
end


%=========================== DRAW 2D MRI SLICE ============================
function M = DrawMRI(Electrode)
    global Fig Grid Brain Atlas Layer
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(4));                                                          % Select axes #4 to display MRI slice
 	Z = -Electrode(Electrode(1).Selected).CurrentDepth+Electrode(Electrode(1).Selected).TipLength+(Electrode(Electrode(1).Selected).CurrentSelected-1)*Electrode(Electrode(1).Selected).ContactSpacing;
 	SlicePosMM = ApplyTform([Electrode(Electrode(1).Selected).Target, Z, 1]);                                                                    % Get current selected contact coordinates (mm)
  	SliceThicknessMM = 1;
    
        
    %=============== FOR EACH STRUCTURE/ LAYER...    
    for Ln = 1:numel(Layer.MRI)
        
        %=============== GET SLICE INDEX
        Layer.MRI(Ln).CurrentSlice = round(Layer.MRI(Ln).OriginVox) + round(SlicePosMM./Layer.MRI(Ln).VoxelDim);           % Get slice index of current selected contact
        X = 1:Layer.MRI(Ln).DimVox(1);
        Y = 1:Layer.MRI(Ln).DimVox(2);
        Z = 1:Layer.MRI(Ln).DimVox(3);
        switch Layer.CurrentSliceView
            case 1      %==================== SAGITTAL
                X = Layer.MRI(Ln).CurrentSlice(Layer.CurrentSliceView);
               	xPos = repmat(SlicePosMM(Layer.CurrentSliceView),[2,2]) + Layer.MRI(Ln).VoxelDim(Layer.CurrentSliceView)*(Ln-2);
                yPos = [Layer.MRI(Ln).BoundsCorMM; Layer.MRI(Ln).BoundsCorMM];
                zPos = repmat(Layer.MRI(Ln).BoundsAxMM,[2,1])';
            case 2      %==================== CORONAL
                Y = Layer.MRI(Ln).CurrentSlice(Layer.CurrentSliceView);
                xPos = [Layer.MRI(Ln).BoundsSagMM; Layer.MRI(Ln).BoundsSagMM];
                yPos = repmat(SlicePosMM(Layer.CurrentSliceView),[2,2]) + Layer.MRI(Ln).VoxelDim(Layer.CurrentSliceView)*(Ln-2);
                zPos = repmat(Layer.MRI(Ln).BoundsAxMM,[2,1])';
            case 3      %==================== AXIAL
                Z = Layer.MRI(Ln).CurrentSlice(Layer.CurrentSliceView);
               	xPos = repmat(Layer.MRI(Ln).BoundsSagMM,[2,1])';
                yPos = [Layer.MRI(Ln).BoundsCorMM; Layer.MRI(Ln).BoundsCorMM];
                zPos = repmat(SlicePosMM(Layer.CurrentSliceView),[2,2]) + Layer.MRI(Ln).VoxelDim(Layer.CurrentSliceView)*(Ln-2);
        end
        %=============== CHECK REQUESTED SLICE IS WITHIN DATA RANGE
        if any([X,Y,Z] <= 0) || any([max(X),max(Y),max(Z)] > Layer.MRI(Ln).DimVox)
            fprintf('Requested slice out of volume!\n');
            CurrentMRISlice = zeros(numel(X), numel(Y), numel(Z));
            CurrentAlpha = [];
        else
            %=============== GET SLICE DATA
            CurrentMRISlice = squeeze(Layer.MRI(Ln).img(X,Y,Z));
            if ~isempty(Layer.MRI(Ln).AlphaMaskVolume)
                CurrentAlpha = squeeze(Layer.MRI(Ln).AlphaMaskVolume(X,Y,Z))*Layer.Opacity(Ln);                                     % Get current slice alpha layer
            else
                CurrentAlpha = [];
            end
        end
        %=============== REORIENT SLICE
      	if Layer.CurrentSliceView <3
            CurrentMRISlice = flipud(rot90(CurrentMRISlice));
            CurrentAlpha = flipud(rot90(CurrentAlpha));
        end
        %=============== APPLY INTENSITY SCALING
        if Ln == 2
            CurrentMRISlice = ((CurrentMRISlice-Layer.MRI(Ln).MRImin)/(Layer.MRI(Ln).MRImax-Layer.MRI(Ln).MRImin))+Ln-1;
        elseif Ln > 2
            CurrentMRISlice = repmat(CurrentMRISlice, [1,1,3]);
            for rgb = 1:3
                CurrentMRISlice(:,:,rgb) = CurrentMRISlice(:,:,rgb)*Layer.Colors(Ln, rgb);
            end
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
        if ~isfield(Layer.MRI,'ImageHandle') || isempty(Layer.MRI(Ln).ImageHandle) 	%=============== If image handle does not yet exist...
            Layer.MRI(Ln).ImageHandle = surf(xPos,yPos,zPos,'CData',CurrentMRISlice,'FaceColor','texturemap','EdgeColor','none');  	% Draw MRI slice to axes
            hold on;
            if ~isempty(CurrentAlpha)
                set(Layer.MRI(Ln).ImageHandle,'FaceAlpha','texturemap', 'alphadata', CurrentAlpha);                              	% Set slice alpha in axes
            end 
            if numel(Layer.On) < Ln
                Layer.On(Ln) = 1;
            end
            if Layer.On(Ln) == 0
                set(Layer.MRI(Ln).ImageHandle, 'visible', 'off');
            end
            if Ln == 2
                set(Layer.MRI(Ln).ImageHandle, 'ButtonDownFcn', {@AtlasSelection, Ln});                                         	% Set callback function for contact selection via mouse       
            end
        elseif isfield(Layer.MRI,'ImageHandle')                                     %=============== If image handle already exists...
            if ~isempty(Layer.MRI(Ln).ImageHandle) && ishandle(Layer.MRI(Ln).ImageHandle)
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
    set(gca,'Clim',[0 2],'TickDir','out');
    
    if Fig.CoordinatesInMM == 1
        title(sprintf('[XYZ] = %.2f, %.2f, %.2f mm', SlicePosMM), 'fontsize',16, 'units','normalized','pos',[0 1.01],'HorizontalAlignment','left');
    elseif Fig.CoordinatesInMM == 0
        SlicePosVox = Layer.MRI(1).OriginVox + round(SlicePosMM./Layer.MRI(1).VoxelDim);
        title(sprintf('[XYZ] = %d, %d, %d voxels', SlicePosVox), 'fontsize',16, 'units','normalized','pos',[0 1.01],'HorizontalAlignment','left');
    end

  	if Layer.ZoomOn==1                          %================== ZOOM ON
        Contacts = find(isgraphics2(Electrode(Electrode(1).Selected).E{4}));
        ZoomedXlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'xdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'xdata'),2))]);
        ZoomedYlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'ydata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'ydata'),2))]);
        ZoomedZlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'zdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'zdata'),2))]);
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
    DrawStructureOutline;                           % Update structure outline (if on)
end


%========================= DRAW 3D BRAIN SURFACE ==========================
function DrawStructureOutline
global Layer Fig
    axes(Fig.PlotHandle(4));
    indx = Layer.CurrentStructure;
    XYZmm = Layer.MRI(indx).SelectedXYZ;
    XYZmm(Layer.CurrentSliceView) = Layer.MRI(Layer.CurrentStructure).CurrentSlice(Layer.CurrentSliceView);
    
    %========= Delete current outline and label text
    if isfield(Layer.MRI(indx), 'text_handle') && ishandle(Layer.MRI(indx).text_handle)
        delete(Layer.MRI(indx).text_handle);
    end
    if isfield(Layer.MRI(indx),'Outline') && ~isempty(Layer.MRI(indx).Outline{1}) && ishandle(Layer.MRI(indx).Outline{1}(1))
        for i = 1:numel(Layer.MRI(indx).Outline)
            delete(Layer.MRI(indx).Outline{i});
            Layer.MRI(indx).Outline{i} = [];
        end
    end
    
    if Layer.MRI(indx).SelectedStructIndx > 0                                                           % If a structure is selected...
        
        %================== Draw structure outline
        if get(Layer.InputHandle(6),'value')==1                                                         % if 'Outline on' is selected and structure was selected...
            StructureVolume = Layer.MRI(indx).img(:,:,:);                                               % Create binary mask for selected structure
            StructureVolume(StructureVolume~= Layer.MRI(Layer.CurrentStructure).SelectedStructIndx) = 0;
            StructureVolume(StructureVolume== Layer.MRI(Layer.CurrentStructure).SelectedStructIndx) = 1;
            switch Layer.CurrentSliceView
                case 1
                    SliceImage = squeeze(StructureVolume(Layer.MRI(Layer.CurrentStructure).CurrentSlice(Layer.CurrentSliceView),:,:));
                case 2
                    SliceImage = squeeze(StructureVolume(:,Layer.MRI(Layer.CurrentStructure).CurrentSlice(Layer.CurrentSliceView),:));
                case 3
                    SliceImage = squeeze(StructureVolume(:,:,Layer.MRI(Layer.CurrentStructure).CurrentSlice(Layer.CurrentSliceView)));
            end
            if sum(SliceImage(:)) > 0                                                                      % If currently selected structure appears in current slice...
                B = bwboundaries(SliceImage);
                for b = 1:numel(B)
                    switch Layer.CurrentSliceView
                        case 1
                            if ~isfield(Layer.MRI(indx).ImageHandle, 'XData')               % Deal with MATLAB < 2014b graphics handles!
                                Xpos = get(Layer.MRI(indx).ImageHandle, 'XData');
                                InplaneMM = Xpos(1,1)+0.5;
                            else
                                InplaneMM = Layer.MRI(indx).ImageHandle.XData(1,1)+0.5;
                            end
                            B{b} = (B{b}-repmat(Layer.MRI(indx).OriginVox([2,3]), [size(B{b},1), 1])).*repmat(Layer.MRI(indx).VoxelDim([2,3]), [size(B{b},1), 1]);
                            Layer.MRI(indx).Outline{b} = plot3(repmat(InplaneMM, [size(B{b},1),1]), B{b}(:,1), B{b}(:,2));
                        case 2
                        	if ~isfield(Layer.MRI(indx).ImageHandle, 'YData')               % Deal with MATLAB < 2014b graphics handles!
                                Xpos = get(Layer.MRI(indx).ImageHandle, 'YData');
                                InplaneMM = Xpos(1,1)+0.5;
                            else
                                InplaneMM = Layer.MRI(indx).ImageHandle.YData(1,1)+0.5;
                            end
                            B{b} = (B{b}-repmat(Layer.MRI(indx).OriginVox([1,3]), [size(B{b},1), 1])).*repmat(Layer.MRI(indx).VoxelDim([1,3]), [size(B{b},1), 1]);
                            Layer.MRI(indx).Outline{b} = plot3(B{b}(:,1), repmat(InplaneMM, [size(B{b},1),1]), B{b}(:,2));
                        case 3
                        	if ~isfield(Layer.MRI(indx).ImageHandle, 'ZData')               % Deal with MATLAB < 2014b graphics handles!
                                Xpos = get(Layer.MRI(indx).ImageHandle, 'ZData');
                                InplaneMM = Xpos(1,1)+0.5;
                            else
                                InplaneMM = Layer.MRI(indx).ImageHandle.ZData(1,1)+0.5;
                            end
                            B{b} = (B{b}-repmat(Layer.MRI(indx).OriginVox([1,2]), [size(B{b},1), 1])).*repmat(Layer.MRI(indx).VoxelDim([1,2]), [size(B{b},1), 1]);
                            Layer.MRI(indx).Outline{b} = plot3(B{b}(:,1), B{b}(:,2), repmat(InplaneMM, [size(B{b},1),1]));
                    end
                    set(Layer.MRI(indx).Outline{b}, 'color', Layer.Colors(indx,:),'linewidth',3);
                    hold on;
                end

                %================== Draw structure label
                [SelectedIndx, SelectedStructs] = ENT_GetStructureIndex(Layer.MRI(indx).SelectedStructIndx);    % Get structure name
                SelectedStructs{1}(strfind(SelectedStructs{1}, '_')) = ' ';                                     % Replace underscores with space
                SelectedStructs{1}(1:2) = [];                                                                   % Remove hemisphere label (for Neuromaps)
                XYZmm(3) = -XYZmm(3);
                Layer.MRI(indx).text_handle = text(XYZmm(1), XYZmm(2), XYZmm(3), SelectedStructs{1});           % 
                set(Layer.MRI(indx).text_handle,'Color',[1 1 1], 'fontsize', 18);                               % Set text appearance
            end
        end
    end
    if numel(Fig.PlotHandle)>=5
        uistack(Fig.PlotHandle(5), 'top')
    end
end


%========================= DRAW 3D BRAIN SURFACE ==========================
function Brain = DrawBrain3D(Brain, Electrode, Grid)
    global Fig Surface
    figure(Fig.Handle);
    
    %======================== LOAD CORTICAL SURFACE
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
    camlight('infinite');
    lighting phong;
    colormap bone;
    axis(gca,'vis3d');                                      % Maintain axes ratio (do not scale)     
    Brain.Labels(1) = xlabel('Medial-Lateral','Fontsize',Fig.FontSize);                                        
    Brain.Labels(2) = ylabel('Posterior-Anterior','Fontsize',Fig.FontSize);
    Brain.Labels(3) = zlabel('Inferior-Superior','Fontsize',Fig.FontSize);
    grid on;
    axis equal;
    set(Brain.Object,'SpecularStrength',Brain.Specular,'AmbientStrength',Brain.Ambient,'DiffuseStrength',Brain.Diffuse);


    %======================== LOAD OTHER STUCTURES 
    if ~isempty(Surface.StructVTKs)
        Surface.ObjectVis = ones(1,numel(Surface.StructVTKs));
        for s = 1:numel(Surface.StructVTKs)
            [v,f] = read_vtk(Surface.StructVTKs{s});
            FV.vertices = v';
            FV.faces = f';
            FV.facevertexcdata = Brain.SurfaceColors(s,:);
            FV.facecolor = 'flat';
            FV.facealpha = 1;
            FV.edgecolor = 'none';    
            Surface.Object(s) = patch(FV,'EdgeColor','none');
            set(Surface.Object(s),'Facecolor',Brain.SurfaceColors(s,:));
            if Surface.ObjectVis(s) == 1
                set(Surface.Object(s),'Visible','on');
            elseif Surface.ObjectVis(s) == 0
                set(Surface.Object(s),'Visible','off');
            end
        end
    end


    %=============== Draw chamber & grid holes
    hold on;
    GridFV.vertices = ApplyTform(Grid.vertices);
    GridFV.faces = Grid.faces;
    Brain.Chamber = patch(GridFV, 'FaceColor', Grid.RGB, 'EdgeColor', 'none');
%     set(Brain.Chamber,'FaceLighting','phong');
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

    set(Brain.Object,'HitTest','on');
end


%======================= DRAW CONTACTS SCHEMATIC ==========================
function Electrode = DrawContacts(Electrode)
    global Fig
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(5));                                      % Set current axes to electrode contact schematic
    cla;                                                                                    % Clear axes
    Electrode(Electrode(1).Selected).ContactRadius = 2;                                 	% Set schematic dimension parameters...
    ContactSpacing  = 2*Electrode(Electrode(1).Selected).ContactRadius+2;
    ShaftRadius     = 5;
    TipLength       = 20;
    FullLength      = (Electrode(Electrode(1).Selected).ContactNumber*ContactSpacing)+TipLength;                        
    Electrode(Electrode(1).Selected).ContactPos = linspace(TipLength,FullLength-(Electrode(Electrode(1).Selected).ContactRadius*2), Electrode(Electrode(1).Selected).ContactNumber);
    X = [0 -ShaftRadius -ShaftRadius ShaftRadius ShaftRadius];
    Y = [0 TipLength FullLength FullLength TipLength];       
    X2 = [0 -2 2];
    Y2 = [2 10 10];
    Electrode(Electrode(1).Selected).C(1) = patch(X,Y,Electrode(Electrode(1).Selected).Color);                   	% Draw electrode shaft
    Electrode(Electrode(1).Selected).Tip = patch(X2 ,Y2 ,[0 0 0], 'edgecolor','none', 'linewidth',2,'ButtonDownFcn',@ElectrodeClickCallback); 	% Draw electrode tip
    hold on;
    for cont = 1:Electrode(Electrode(1).Selected).ContactNumber                                                 	% For each contact
        Electrode(Electrode(1).Selected).C(1+cont) = FillCircle([0, Electrode(Electrode(1).Selected).ContactPos(cont)],Electrode(Electrode(1).Selected).ContactRadius,100, Electrode(Electrode(1).Selected).QualityColorMap(Electrode(Electrode(1).Selected).ContactData(cont)+1,:));
    end
    Electrode(Electrode(1).Selected).CurrentSelectedHandle = PlotCircle(0,Electrode(Electrode(1).Selected).ContactPos(Electrode(Electrode(1).Selected).CurrentSelected),Electrode(Electrode(1).Selected).ContactRadius,Electrode(Electrode(1).Selected).SelectionColor);
    set(Electrode(Electrode(1).Selected).CurrentSelectedHandle,'LineWidth', 2);
    axis equal tight;
    set(gca,'YTick', Electrode(Electrode(1).Selected).ContactPos, 'YTickLabel', 1:Electrode(Electrode(1).Selected).ContactNumber, 'YAxisLocation', 'right');        
    set(gca,'color',Fig.AxesBkgColor(1,:));                                                                         % Set axis background to match figure
    set(gca,'xcolor',Fig.Background,'xtick',[],'xlim',[-6 6]);                                                    	% Hide x-axis
    set(Electrode(Electrode(1).Selected).C(2:end),'ButtonDownFcn',@ElectrodeClickCallback);                         % Set callback function for contact selection via mouse
    
    %========== Set context menu for quality rating
    hcmenu = uicontextmenu;
    for i = 1:size(Electrode(Electrode(1).Selected).QualityColorMap,1)
        item(i) = uimenu(hcmenu,'Label',num2str(i-1),'Callback',{@ContactContextmenu,i});
    end
    set(Electrode(Electrode(1).Selected).C(2:end),'uicontextmenu',hcmenu);
end



%% =========================== CALLBACKS ==================================

function out = isgraphics2(in)
    if ~exist('isgraphics.m','file')
        out = ishandle(in);
    else
        out = isgraphics(in);
    end
end

%========================== GRID HOLE SELECTION
function GridClickCallback(objectHandle, eventData)
global Button Electrode Grid Layer
    axesHandle  = get(objectHandle,'Parent');
    Grid.CurrentSelected = find(Grid.Object==objectHandle);
    Electrode(Electrode(1).Selected).Target = Grid.Coordinates(Grid.CurrentSelected,:);
	Layer.M = DrawMRI(Electrode);                                   % Draw current MRI slice
    Electrode = DrawElectrode(Electrode);                           % Move electrode
    Electrode(Electrode(1).Selected).GT = DrawGuidetube(Electrode);	% Move guide tube
    for i = 1:2
        set(Button.InputHandle(i),'String',num2str(Electrode(Electrode(1).Selected).Target(i)));             % Update grid hole selection in input boxes
    end
end

%========================== CONTACT SELECTION
function ElectrodeClickCallback(objectHandle, eventData)
global Electrode Contact
    axesHandle  = get(objectHandle,'Parent');
    coordinates = get(axesHandle,'CurrentPoint');
    Ypos = coordinates(1,2);                           
    delete(Electrode(Electrode(1).Selected).CurrentSelectedHandle);                                                             % Delete the previously selected contact highlight
    if Electrode(Electrode(1).Selected).Tip == objectHandle
        set(Electrode(Electrode(1).Selected).Tip, 'edgecolor',[1 1 1]);
     	set(Contact.InputHandle(1),'String','tip');                                                                             % Update text to show current contact #
        set(Contact.InputHandle(2),'String',' ');
        Electrode(Electrode(1).Selected).CurrentSelected = nan;
    else
      	set(Electrode(Electrode(1).Selected).Tip, 'edgecolor','none');
        Electrode(Electrode(1).Selected).CurrentSelected = find(Electrode(Electrode(1).Selected).C==objectHandle)-1;          	% Find selected contact #
        Electrode(Electrode(1).Selected).CurrentSelectedHandle = PlotCircle(0,Electrode(Electrode(1).Selected).ContactPos(Electrode(Electrode(1).Selected).CurrentSelected),Electrode(Electrode(1).Selected).ContactRadius,Electrode(Electrode(1).Selected).SelectionColor);
        set(Electrode(Electrode(1).Selected).CurrentSelectedHandle,'LineWidth', 2);                        
        set(Contact.InputHandle(1),'String',num2str(Electrode(Electrode(1).Selected).CurrentSelected));                         % Update text to show current contact #
        set(Contact.InputHandle(2),'String',num2str(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected)));    % Update text to show current contact value
    end
    Electrode = DrawCurrentContact(Electrode);                                                                                          % Update plot to show current contact
    DrawMRI(Electrode);
end

%============ UPDATE CONTACT QUALITY RATING
function ContactContextmenu(src,evt, i)
    global Electrode Contact
    set(gco,'FaceColor', Electrode(Electrode(1).Selected).QualityColorMap(i,:));
   	Electrode(Electrode(1).Selected).CurrentSelected = find(Electrode(Electrode(1).Selected).C== gco)-1;  	% Find selected contact #
	Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected) = i-1;
    set(Contact.InputHandle(2),'String',num2str(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected))); 
end

%========================== MRI SELECTION
function AtlasSelection(objectHandle, eventData, indx)
global Layer
    axesHandle  = get(objectHandle,'Parent');
    if indx == 1            %============= Anatomical MRI was clicked...
        pan on; 
    elseif indx >= 2        %============= Atlas structure was clicked...
    	XYZmm = get(axesHandle,'Currentpoint');
     	XYZmm(:,[2, 3]) = -XYZmm(:,[2, 3]);                                                      	% Flip y and z dimension (because slice image is flipped in DrawMRI)
        XYZvx = Layer.MRI(indx).OriginVox - round(XYZmm(1,:)./Layer.MRI(indx).VoxelDim);        
        XYZvx(Layer.CurrentSliceView) = Layer.MRI(indx).CurrentSlice(Layer.CurrentSliceView);
        Layer.MRI(indx).SelectedStructIndx = Layer.MRI(indx).img(XYZvx(1), XYZvx(2), XYZvx(3));
        if Layer.CurrentSliceView == 1
            XYZmm(:,2) = -XYZmm(:,2); 
        else
            XYZmm(:,[2,3]) = -XYZmm(:,[2,3]);                                                                   % Unflip y dimension (because selection is not flipped)
        end
        
        %=========== Update GUI
        XYZmm = XYZmm(1,:);
        Layer.MRI(indx).SelectedXYZ = XYZmm;
        DrawStructureOutline;                                                                           % Draw structure outline
    end
    
end

%========================== UPDATE SESSION PARAMETERS
function SessionParams(hObj, Event, Indx)
global Electrode Session Contact Button Defaults
    switch Indx                                                         % If updated variable was...
        case 2      %==================== Session date
            SelectedDate = Session.DateStrings(get(hObj,'Value'),:);                            % Get selected date string
            if ~strcmp(SelectedDate, date)                                                      % If selected date is not todays date...
                Params = ENT_LoadSessionParams(Defaults.HistoryFile, SelectedDate);             % Load session parameters for selected date  
                LoadNewSession(Params);
            else                                                                                % If todays date was selected...
                Session.Date     	= SelectedDate;
                Params.Date       	= SelectedDate;                                             % Record session date string
                Params.DateString  	= SelectedDate;
                Params.DateIndex  	= get(hObj,'Value');
                Session.DateIndx    = Params.DateIndex;
            end
            
        case 3      %==================== Electrode number
            delete(Electrode(Electrode(1).Selected).C);                                         % Delete contacts schematic
           	Electrode(Electrode(1).Selected).C = [];                                            % Empty contacts graphcis handles
            [Electrode.Selected] = deal(get(hObj,'Value'));                                     
            Button.CurrentValues = [Electrode(Electrode(1).Selected).Target(1),Electrode(Electrode(1).Selected).Target(2),Electrode(Electrode(1).Selected).StartDepth, Electrode(Electrode(1).Selected).MicrodriveDepth, Electrode(Electrode(1).Selected).CurrentDepth, Electrode(Electrode(1).Selected).GuideLength];
            for i = 1:numel(Button.CurrentValues)
                set(Button.InputHandle(i),'String',num2str(Button.CurrentValues(i)));
            end  
            ElectrodeType = find(~cellfun(@isempty, strfind(Electrode(1).AllTypes, Electrode(Electrode(1).Selected).Brand)));
            set(Session.InputHandle(4), 'value', ElectrodeType);
            set(Session.InputHandle(5), 'string', num2str(Electrode(Electrode(1).Selected).ContactNumber));
          	SessionParams(Session.InputHandle(5),[],5);                                         % Update number of channels
            Layer.M = DrawMRI(Electrode);                                                       % Draw new MRI sections
            
        case 4      %==================== Electrode type
            AllBrands = get(hObj,'String');
            Electrode(Electrode(1).Selected).Brand = AllBrands{get(hObj,'Value')};
            Electrode(Electrode(1).Selected).ID = sprintf('%s%d', Electrode(Electrode(1).Selected).Brand, Electrode(Electrode(1).Selected).ContactNumber);
            Electrode = ENT_GetElectrodeParams(Electrode);                  % Get electrode parameters based on electrode ID
            Electrode = DrawContacts(Electrode);                    	
            
        case 5      %==================== Electrode contacts
             Electrode(Electrode(1).Selected).ContactNumber = str2num(get(hObj,'String'));
             if ~isempty(Electrode(Electrode(1).Selected).C) && isgraphics(Electrode(Electrode(1).Selected).C(1))
                 delete(Electrode(Electrode(1).Selected).C);
                 Electrode(Electrode(1).Selected).C = [];
             end
             if Electrode(Electrode(1).Selected).ContactNumber > numel(Electrode(Electrode(1).Selected).ContactData)
             	Electrode(Electrode(1).Selected).ContactData(end+1:Electrode(Electrode(1).Selected).ContactNumber) = 0;
             elseif Electrode(Electrode(1).Selected).ContactNumber < numel(Electrode(Electrode(1).Selected).ContactData)
                 Electrode(Electrode(1).Selected).ContactData((Electrode(Electrode(1).Selected).ContactNumber+1):end) = [];
             end
             if Electrode(Electrode(1).Selected).ContactNumber < Electrode(Electrode(1).Selected).CurrentSelected
                 Electrode(Electrode(1).Selected).CurrentSelected = Electrode(Electrode(1).Selected).ContactNumber;
                 set(Contact.InputHandle(1),'String',num2str(Electrode(Electrode(1).Selected).CurrentSelected));                           % Update text to show current contact #
                 set(Contact.InputHandle(2),'String',num2str(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected)));    % Update text to show current contact #
                
             end
             Electrode = DrawContacts(Electrode);                           % Re-draw electrode schematic
             Electrode = DrawElectrode(Electrode);                          % Re-draw 3D electrode objects

    end
end

%========================== UPDATE ELECTRODE POSITION =====================
function ElectrodePos(hObj, Event, Indx)
    global Electrode Fig Layer Button Grid
    set(Fig.Handle, 'currentaxes', Fig.PlotHandle(1));                      % Set current axes to 3D view
    switch Indx                                                             % If updated variable was...
        case 3                                                              % 3 = Start depth (manual)
            Electrode(Electrode(1).Selected).StartDepth = str2num(get(hObj,'String'));
            Electrode(Electrode(1).Selected).CurrentDepth = Electrode(Electrode(1).Selected).StartDepth+Electrode(Electrode(1).Selected).MicrodriveDepth;
            set(Button.InputHandle(5),'String',num2str(Electrode(Electrode(1).Selected).CurrentDepth));
            
        case 4                                                              % 4 = EPS depth
            Electrode(Electrode(1).Selected).MicrodriveDepth = str2num(get(hObj,'String'));
            Electrode(Electrode(1).Selected).CurrentDepth = Electrode(Electrode(1).Selected).StartDepth+Electrode(Electrode(1).Selected).MicrodriveDepth;
            set(Button.InputHandle(5),'String',num2str(Electrode(Electrode(1).Selected).CurrentDepth));
            
        case 5                                                              % 5 = Total depth
            Electrode(Electrode(1).Selected).CurrentDepth = str2num(get(hObj,'String'));
            
            
        case 6
            Electrode(Electrode(1).Selected).GuideLength = str2num(get(hObj,'String'));              % 6 = Guide tube length
            delete(Electrode(Electrode(1).Selected).GT);                 	% Delete current guide tube object
            Electrode(Electrode(1).Selected).GT = DrawGuidetube(Electrode);	% Draw new guide tube object
    end
    if Indx < 3
        Electrode(Electrode(1).Selected).Target(Indx) = str2num(get(hObj,'String'));
        delete(Electrode(Electrode(1).Selected).GT);                      	% Delete current guide tube object
      	Electrode(Electrode(1).Selected).GT = DrawGuidetube(Electrode);   	% Draw new guide tube object
    end
    if Indx <=5                                                             % If contact position changed...
        Layer.M = DrawMRI(Electrode);                                       % Draw new MRI sections
    end
    Electrode = DrawElectrode(Electrode);                                   % Draw new electrode object
    Electrode = DrawCurrentContact(Electrode);
    drawnow;                                                                % Refresh figure
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
    global Layer Fig Electrode
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
            if isfield(Layer.MRI(Layer.CurrentStructure),'Outline') && ishandle(Layer.MRI(Layer.CurrentStructure).Outline{1}(1)) 
                for b = 1:numel(Layer.MRI(Layer.CurrentStructure).Outline)
                    set(Layer.MRI(Layer.CurrentStructure).Outline{b}, 'color', Layer.Colors(Layer.CurrentStructure,:));
                end
            end
            
        case 4                          %============== Update layer transparency
            Layer.Opacity(Layer.CurrentStructure) = get(hObj,'Value');
            ValueString = sprintf('%.0f %%', Layer.Opacity(Layer.CurrentStructure)*100);
            set(Layer.LabelHandle(4), 'string',['Opacity (',ValueString,')']);
            
        case 5                    	%============== Update gaussian blur
            Layer.sigma(Layer.CurrentStructure) = max([get(hObj,'Value')*Layer.SigmaMax, Layer.SigmaMin]);
            ValueString = sprintf('%.1f mm', Layer.sigma(Layer.CurrentStructure));
            set(Layer.LabelHandle(5), 'string', ['Smoothing (', ValueString,')']);
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
    Layer.M = DrawMRI(Electrode);
    if Indx==1
        Electrode = DrawCurrentContact(Electrode);
    end
    
end



%======================== CONTACT OPTIONS =================================
function ContactSelect(hObj, Event, Indx)
    global Contact Fig Brain Session Electrode Defaults Layer

    switch Indx
        
        case 1  %============== New contact selected
            Electrode(Electrode(1).Selected).CurrentSelected = str2num(get(hObj,'String'));
            if Electrode(Electrode(1).Selected).CurrentSelected > Electrode(Electrode(1).Selected).ContactNumber
                Electrode(Electrode(1).Selected).CurrentSelected = Electrode(Electrode(1).Selected).ContactNumber;
                set(Contact.InputHandle(1),'String',num2str(Electrode(Electrode(1).Selected).CurrentSelected));
            elseif Electrode(Electrode(1).Selected).CurrentSelected < 1
                Electrode(Electrode(1).Selected).CurrentSelected = 1;
                set(Contact.InputHandle(1),'String',num2str(Electrode(Electrode(1).Selected).CurrentSelected));
            end
            set(Contact.InputHandle(2),'String',num2str(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected)));
            set(Fig.Handle, 'currentaxes', Fig.PlotHandle(5));   
            delete(Electrode(Electrode(1).Selected).CurrentSelectedHandle);          
            Electrode(Electrode(1).Selected).CurrentSelectedHandle = PlotCircle(0,Electrode(Electrode(1).Selected).ContactPos(Electrode(Electrode(1).Selected).CurrentSelected),Electrode(Electrode(1).Selected).ContactRadius,Electrode(Electrode(1).Selected).SelectionColor);
            set(Electrode(Electrode(1).Selected).CurrentSelectedHandle,'LineWidth', 2);
            Electrode = DrawCurrentContact(Electrode);
            
        case 2  %============== New contact rating provided
            Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected) = str2num(get(hObj,'String'));
            if Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected) > numel(Electrode(Electrode(1).Selected).QualityColorMap)
                Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected) = numel(Electrode(Electrode(1).Selected).QualityColorMap);
                set(Contact.InputHandle(2),'String',num2str(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected)));
            elseif Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected) < 0
                Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected) = 0;
                set(Contact.InputHandle(2),'String',num2str(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected)));
            end
            QualityColor = Electrode(Electrode(1).Selected).QualityColorMap(Electrode(Electrode(1).Selected).ContactData(Electrode(Electrode(1).Selected).CurrentSelected)+1,:);
            set(Electrode(Electrode(1).Selected).C(Electrode(Electrode(1).Selected).CurrentSelected+1), 'FaceColor', QualityColor);
            
            
        case 3  %============== Adjust MRI view zoom level
            Layer.ZoomLevel = str2num(get(hObj,'string'));
            if Layer.ZoomOn==1                                         %====== Zoom IN
                if exist('isgraphics.m','file')
                    Contacts = find(isgraphics(Electrode(Electrode(1).Selected).E{4}));
                else
                    Contacts = find(ishandle(Electrode(Electrode(1).Selected).E{4}));
                end
                ZoomedXlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'xdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'xdata'),2))]);
                ZoomedYlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'ydata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'ydata'),2))]);
                ZoomedZlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'zdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'zdata'),2))]);
                set(Fig.PlotHandle(4), 'xlim', ZoomedXlims+[-Layer.ZoomLevel, Layer.ZoomLevel],'ylim', ZoomedYlims+[-Layer.ZoomLevel, Layer.ZoomLevel], 'zlim', ZoomedZlims+[-Layer.ZoomLevel, Layer.ZoomLevel]);
            end
            
        case 4  %============== Toggle MRI view zoom to contacts
            Layer.ZoomOn = get(hObj,'value');
            if Layer.ZoomOn==1                                         %====== Zoom IN
                if exist('isgraphics.m','file')
                    Contacts = find(isgraphics(Electrode(Electrode(1).Selected).E{4}));
                else
                    Contacts = find(ishandle(Electrode(Electrode(1).Selected).E{4}));
                end
                ZoomedXlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'xdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'xdata'),2))]);
                ZoomedYlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'ydata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'ydata'),2))]);
                ZoomedZlims = sort([mean(mean(get(Electrode(Electrode(1).Selected).E{4}(3), 'zdata'),2)), mean(mean(get(Electrode(Electrode(1).Selected).E{4}(Contacts(end)), 'zdata'),2))]);
                set(Fig.PlotHandle(4), 'xlim', ZoomedXlims+[-Layer.ZoomLevel, Layer.ZoomLevel],'ylim', ZoomedYlims+[-Layer.ZoomLevel, Layer.ZoomLevel], 'zlim', ZoomedZlims+[-Layer.ZoomLevel, Layer.ZoomLevel]);
                
            elseif Layer.ZoomOn==0                                     %====== Zoom OUT
                set(Fig.PlotHandle(4),'xlim', Layer.MRI(1).BoundsSagMM);
                set(Fig.PlotHandle(4),'ylim', Layer.MRI(1).BoundsCorMM);
            	set(Fig.PlotHandle(4),'zlim', Layer.MRI(1).BoundsAxMM);
            end

        case 5  %============== Reset MRI view to slice containing current contact
        	
        	
            
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


%===================== LOAD DATA FROM PREVIOUS SESSION ====================
function LoadNewSession(Params)
global Electrode Session Button Layer 

    %=========== Delete excess electrode graphic objects
    if numel(Electrode) > Params(1).NoElectrodes
        for e = numel(Electrode):-1:(Params(1).NoElectrodes+1)                                                                	% Delete any additional electrodes from previous session
            if isfield(Electrode,'XhairHandle') && ~isempty(Electrode(e).XhairHandle) && ishandle(Electrode(e).XhairHandle(1)) 	% Check whether a handle to crosshairs exists
                delete(Electrode(e).XhairHandle);
            end
            if isfield(Electrode,'GT') && ~isempty(Electrode(e).GT) && ishandle(Electrode(e).GT(1)) 	% Check whether a handle to guidetube exists
                delete(Electrode(e).GT);
            end
            if isfield(Electrode,'E') && ~isempty(Electrode(e).E)                                       % Check whether a handle to electrode exists
                for i = 1:numel(Electrode(e).E)
                    delete(Electrode(e).E{i});
                end
            end
            Electrode(e) = [];
        end
    end

    %=========== Update variables    
    Session.Date                    = Params(1).DateString;
    Session.DateIndx             	= Params(1).DateIndex;                  
    [Electrode.Numbers]             = deal(1:Params(1).NoElectrodes);
    [Electrode.Selected]            = deal(1);
    [Electrode.StartDepth]          = deal(0);
    [Electrode.MicrodriveDepth]     = deal(0);
  	[Electrode.QualityColorMap]     = deal([0 0 0; 1 0 0; 1 0.5 0; 1 1 0; 0 1 0]);
    for e = 1:Params(1).NoElectrodes
        Electrode(e).Target         = Params(1).Target{e};
        Electrode(e).CurrentDepth   = Params(1).Depth{e};
        Electrode(e).GuideLength    = Params(1).GuideLength{e};
        Electrode(e).ID             = Params(1).ElectrodeID{e};
        Electrode(e).Brand          = Electrode(1).AllTypes{find(strncmp(Electrode(e).ID, Electrode(1).AllTypes, 2))};
    end
 	Electrode                       = ENT_GetElectrodeParams(Electrode);     	% Get remaining default electrode parameters based on electrode ID
    for e = Electrode(1).Numbers
        if ~isempty(Params(1).ContactData) && numel(Params(1).ContactData{1})>1
            Electrode(e).ContactData  	= Params(1).ContactData{e}(1:Electrode(e).ContactNumber);
        else
            Electrode(e).ContactData  	= zeros(1, Electrode(e).ContactNumber);
        end
    end
    
    %=========== Update variables in GUI
    set(Session.InputHandle(2), 'value', Session.DateIndx);
    set(Session.InputHandle(3), 'string', Electrode(1).Numbers, 'value', Electrode(1).Selected);
    set(Session.InputHandle(4), 'value', find(strncmp(Electrode(Electrode(1).Selected).ID, Electrode(1).AllTypes, 2)));
    set(Session.InputHandle(5), 'string', num2str(Electrode(Electrode(1).Selected).ContactNumber));
    Button.CurrentValues = [Electrode(Electrode(1).Selected).Target(1),Electrode(Electrode(1).Selected).Target(2),Electrode(Electrode(1).Selected).StartDepth, Electrode(Electrode(1).Selected).MicrodriveDepth, Electrode(Electrode(1).Selected).CurrentDepth, Electrode(Electrode(1).Selected).GuideLength];
    for i = 1:numel(Button.CurrentValues)
        set(Button.InputHandle(i),'String',num2str(Button.CurrentValues(i)));
    end
    
    %=========== Update plots
    Layer.M = DrawMRI(Electrode);
    for e = Electrode(1).Numbers
        [Electrode.Selected] = deal(e);
        Electrode(e).GT = DrawGuidetube(Electrode); 
      	Electrode = DrawElectrode(Electrode); 
    end
    Electrode = DrawContacts(Electrode);
    Electrode = DrawCurrentContact(Electrode);
    [Electrode.Selected] = deal(1);
    drawnow;
    SessionParams(Session.InputHandle(5),[],5);             	% Update number of channels
                
end




%% ======================== MENU BAR CALLBACKS ============================

%========================== FILE MENU CALLBACK ============================
function FileSelect(hObj, Event, Indx, Indx2)
    global Electrode Fig Session Button Defaults Layer
    Indx2 = 3;  %% <<<<<<< TEMPORARY FUDGE
    switch Indx
        case 1          %============================= LOAD previous session
            Params = ENT_LoadSessionParams(Defaults.HistoryFile);
            LoadNewSession(Params);
   
        case 2  	%============================= SAVE current session
            if exist(Defaults.HistoryFile,'file')==0                                                        % If default Excel file doesntt exist...
              	[Filename, Pathname, Indx] = uiputfile({'.csv';'.xls'}, 'Save current session to...');  	% Ask user to specify file to save to
                if isequal(Filename,0) || isequal(Pathname,0)                                               
                    return
                end
                Defaults.HistoryFile = fullfile(Pathname, Filename);                                        % Set full path of Excel file
            end
  
            CurrentParams{1} = datenum(Session.Date)-datenum('30-Dec-1899');
            for e = 1:numel(Electrode)
                Start = numel(CurrentParams)+1;
                CurrentParams(Start:Start+4) = {Electrode(e).ID, Electrode(e).Target(1), Electrode(e).Target(2), Electrode(e).CurrentDepth, Electrode(e).GuideLength};
            end
            Status = ENT_WriteSessionParams(Defaults.HistoryFile, CurrentParams, [Electrode.ContactData]);
            if Status == 1
                h = msgbox('Session data has been saved.','Save successful!','modal');      % inform user that data was saved
                uiwait(h);  
            else
                h = msgbox('Error saving session data!','Save failed!','modal');
                uiwait(h);  
            end
                                               

        case 3      %============================= EDIT DEFAULTS
            [~,CompName] = system('hostname');
            CompName(find(double(CompName)==10)) = [];
            DefaultParamsFile = fullfile(Session.RootDir, 'Params', sprintf('ParamsFile_%s.mat', CompName));
            Defaults = EN_Initialize(DefaultParamsFile, Session.Subject);
            

        case 4      %============================= CAPTURE figure as print-quality image
            ImFormat = 'png';
            FileName = sprintf('Fig_%s_%s.%s',Session.Subject,datestr(datenum(Session.Date,'dd-mmm-yyyy'),'yyyy-mm-dd'), ImFormat);
            DirName = fullfile(Defaults.ExpDir,'Renders');
            if ~exist(DirName, 'dir')
                mkdir(DirName);
            end
            FullFilename = fullfile(DirName,FileName);
            set(gcf,'InvertHardcopy','off');
            if Indx2 == 1       %========= Capture whole GUI window
                export_fig(FullFilename,['-',ImFormat],'-nocrop');
              	Message = sprintf('Figure was saved to %s', FullFilename);
                h = msgbox(Message,'Saved!');
                
            elseif Indx2 == 2   %========= Copy MRI panel to new figure window
                NewFigH = figure('Color',Fig.Background,...             % Set the figure window background color
                              	'Renderer','OpenGL',...               	% Use OpenGL renderer
                                'OuterPosition', Fig.Rect);          	% position figure window to fit fullscreen;
                s(1) = copyobj(Fig.PlotHandle(4), NewFigH);
                set(s(1),'position',[0.05 0.1 0.4 0.8]);
                colormap gray;
%                 title(sprintf('%s %s - hole = [%d, %d]', Session.Subject, Session.Date, Electrode(Electrode(1).Selected).Target(1), Electrode(Electrode(1).Selected).Target(2)),'units','normalized','position',[0,1.1],'fontsize',18);
                title(sprintf('%s %s - hole = [%d, %d]', Session.Subject, Session.Date, Electrode(Electrode(1).Selected).Target(1), Electrode(Electrode(1).Selected).Target(2)),'horizontalalignment','left','verticalalignment','top','fontsize',18);
                title('');
                s(2) = copyobj(Fig.PlotHandle(4), NewFigH);
                set(s(2),'position',[0.55 0.1 0.4 0.8]);
                set(gca,'zlim',[-20 40],'ylim',[-48 30]);
             	set(s,'clim',[0 1]);
                                title('');
                export_fig(FullFilename,['-',ImFormat],'-nocrop');
                close(NewFigH);
              	Message = sprintf('Figure was saved to %s', FullFilename);
                h = msgbox(Message,'Saved!');
                
            elseif Indx2 == 3
                 NewFigH = figure('Color',Fig.Background,...             % Set the figure window background color
                              	'Renderer','OpenGL',...               	% Use OpenGL renderer
                                'OuterPosition', Fig.Rect);          	% position figure window to fit fullscreen;
                s(1) = copyobj(Fig.PlotHandle(4), NewFigH);
                colormap gray;
                title('');
            end
            
        case 5      %============================= OPEN POST-SESSION STRUCTURAL MRI
            
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
            
        case 6      %============================ QUIT
            close all;
            clear all;
    
    end
end


%========================== EDIT MENU CALLBACK ============================
function EditSelect(hObj, Event, Indx)
    global Electrode Fig Session Button Defaults Layer Brain
    switch Indx
        case 1      %============================ ADD VOLUME OVERLAY
            AllStructures = wildcardsearch(Defaults.VTKdir, '*.nii');
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
            	StructNii(S)    = load_nii(AllStructures{Selection(S)});
                VoxelDim(S,:)   = StructNii(S).hdr.dime.pixdim(2:4);                        % Get voxel dimensions
                VolumeDim(S,:)  = size(StructNii(S).img);                                   % Get volume dimensions
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
            
            
        case 2      %============================ REMOVE VOLUME OVERLAY
            
            
        case 3      %============================ ADD ELECTRODE
          	e = max(Electrode(1).Numbers)+1;                    
            Letters = {'A','B','C','D','E'};
            DefaultElectrodeID = [Electrode(1).Brand, num2str(Electrode(1).ContactNumber), '_', Letters{e}];
            NewID = inputdlg('Enter identifier for new electrode', 'Add electrode',1, {DefaultElectrodeID});
            if isempty(NewID)
                return;
            end
            Electrode(e).ID =               NewID{1};
            [Electrode.Selected]            = deal(e);
            [Electrode.Numbers]             = deal(1:e);
            Electrode(e).StartDepth         = 0;
            Electrode(e).MicrodriveDepth	= 0;
            Electrode(e).QualityColorMap	= Electrode(e-1).QualityColorMap;
            Electrode(e).Target             = [0, 0];
            Electrode(e).CurrentDepth       = 0;
            Electrode(e).GuideLength        = Electrode(e-1).GuideLength;
            Electrode                       = ENT_GetElectrodeParams(Electrode);   	% Get remaining electrode parameters based on electrode ID
            
            %========= Update Params
         	Params(1).NoElectrodes    	= e;
            Params(1).Target{e}         = Electrode(e).Target;
            Params(1).Depth{e}          = Electrode(e).CurrentDepth;
            Params(1).GuideLength{e}    = Electrode(e).GuideLength;
            Params(1).ElectrodeID{e}    = Electrode(e).ID;
            
            %======== Update GUI display
            set(Session.InputHandle(3), 'string', Electrode(1).Numbers, 'value', Electrode(1).Selected);
            set(Session.InputHandle(4), 'value', find(strncmp(Electrode(Electrode(1).Selected).ID, Electrode(1).AllTypes, 2)));
            set(Session.InputHandle(5), 'string', num2str(Electrode(Electrode(1).Selected).ContactNumber));
            SessionParams(Session.InputHandle(3),[],3);             	% Update number of channels
            
            
        case 4      %============================ DELETE ELECTRODE
            if numel(Electrode)==1
                error('User attempted to delete only electrode! There must be a minimum of one electrode (/optrode/ cannula) per session.');
            end
            
            %======== Delete graphics objects
            for i = 1:numel(Electrode(Electrode(1).Selected).E)
                delete(Electrode(Electrode(1).Selected).E{i}); 
            end
            delete(Electrode(Electrode(1).Selected).GT);
            delete(Electrode(Electrode(1).Selected).XhairHandle);
            
            %======== Update parameters
            Electrode(Electrode(1).Selected)= [];      
            [Electrode.Selected]           	= deal(1);
            [Electrode.Numbers]           	= deal(1:numel(Electrode));
            
            %======== Update GUI display
            set(Session.InputHandle(3), 'string', [Electrode.Numbers], 'value', Electrode(1).Selected);
            set(Session.InputHandle(4), 'value', find(strncmp(Electrode(Electrode(1).Selected).ID, Electrode(1).AllTypes, 2)));
            set(Session.InputHandle(5), 'string', num2str(Electrode(Electrode(1).Selected).ContactNumber));
            SessionParams(Session.InputHandle(3),[],3);             	% Update number of channels
            
        case 5  %============================ ADJUST GRID TRANSFORM MATRIX
            ENT_SetGridTransform(Defaults.MRI, Defaults.Xform);
            
            
        case 6  %============================ ADJUST MRI APPEARANCE    
            
            
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
            Message = sprintf('No analysed data found for %s, contact # %d!', Session.Date, Electrode(Electrode(1).Selected).CurrentSelected);
            h = msgbox(Message,'Error');
            return;
        else
            FileName = sprintf('%s-%s-%s-%s-neuResp-ch%d-*', Session.Subject, DateDir, SessionDirs(1).name(end), ExperimentName,Electrode(Electrode(1).Selected).CurrentSelected);
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
        switch Indx2
            case 1
                GridHistHandle = EN_GridHistory(Defaults.HistoryFile,Indx2, Defaults.GridID);
            case 2
                GridHistHandle = EN_GridHistory(Defaults.HistoryFile,Indx2, Defaults.GridID);
            case 3
                ENT_RecordingHistory3D(Session.Subject);
        end

end
end