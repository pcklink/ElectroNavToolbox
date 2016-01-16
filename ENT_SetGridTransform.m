
%====================== ENT_SetGridTransform.m ============================
% This function loads and displays an anatomical MRI with gadolinium-filled
% grid in place. The user may then manually adjust the position and
% orientation of the grid to match the scan, and the resulting
% transformation matrix is saved.
%
%
% ELECTRONAV TOOLBOX
% Developed by Aidan Murphy, � Copyleft 2015, GNU General Public License
%==========================================================================

function ENT_SetGridTransform(NiiFile)


clear all
global Fig Grid nii FV

%============= LOAD DATA
if nargin == 0
%     [file, path]        = uigetfile({'*.nii'}, 'Select ACPC-aligned grid scan');
%     NiiFile             = fullfile(path, file);
    NiiFile             = '/Volumes/rawdata/murphya/MRI/Dexter/20151203/Dexter_20151203_MDEFT_hi_ACPC.nii';
%     NiiFile             = '/Volumes/rawdata/murphya/MRI/Dexter/20151209/Dexter_20151209_ACPC_origin.nii';
    Grid.TformFile          = '/Volumes/PROJECTS/murphya/EN_data/Subjects/Dexter/ManualXform.mat';
end
nii = LoadMRI(NiiFile);

[~,Grid.TformName]      = fileparts(Grid.TformFile);
T                       = load(Grid.TformFile);
Grid.Tform             	= T.T;
Grid.VolFile           	= 'Grid1.nii';
Grid.SurfFile         	= 'Grid1.stl';
Grid.nii              	= load_nii(Grid.VolFile);                 	% Load grid volume
[FV.vertices, FV.faces]	= stlread(Grid.SurfFile);                  	% Load grid surface
Grid.RotDeg            	= [17, 0, 0];                               % Rotations about cardinal axes (degrees)
Grid.RotRad             = Grid.RotDeg/180*pi;
Grid.Trans              = Grid.Tform(1:3,4)';                     	% Translations relative to AC origin
Grid.Tform             	= makehgtform('translate',Grid.Trans(1), Grid.Trans(2), Grid.Trans(3),'xrotate',Grid.RotRad(1),'yrotate',Grid.RotRad(2),'zrotate',Grid.RotRad(3));
FV(2)                   = FV(1);
% FV(2).vertices          = ENT_ApplyTform(Grid.Tform, FV(1).vertices);
Grid.Colors            	= [1 0 0; 0 1 0];
Grid.Alpha              = 0.5;

%% ========================== OPEN FIGURE WINDOW ==========================
Fig.Handle      = figure('position', get(0, 'ScreenSize'),'name', 'ENT_SetGridTransform');
Fig.axh         = tight_subplot(2,3,0.05, 0.05, 0.05);
delete(Fig.axh([3,6]));
Fig.axh([3,6])  = [];
Fig.UIFontsize  = 14;
Fig.Background  = get(Fig.Handle, 'color');


%=============== MRI GUI PANEL
Fig.MRI.BoxPos      = [0.75,0.6,0.2,0.3];
Fig.MRI.InputDim    = [120 20];
Fig.MRI.Labels      = {'Anatomical','Resolution (mm)','Dimensions (voxels)','Origin (voxels)','Permute','Save volume', 'Rotate 90', 'Contrast'};
Fig.MRI.Style       = {'pushbutton','edit','edit','edit','pushbutton','pushbutton','pushbutton','pushbutton'};
Fig.MRI.List        = {nii.filename, nii.VoxDim, nii.DimVox, nii.OriginVox, 'Permute', 'Save', 'Rotate 90', 'Contrast'};
Fig.MRI.UIhandle    = uipanel('Title','Anatomical MRI','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','normalized','Position',Fig.MRI.BoxPos);
Fig.MRI.InputSizes  = [150, 40, 40, 40, 100, 100, 100, 100];
for i = 1:numel(Fig.MRI.Labels)
    Pos = numel(Fig.MRI.Labels)-i;
    Fig.MRI.LabelPos{i} = [20, 10+Pos*Fig.MRI.InputDim(2)*1.5, Fig.MRI.InputDim];
    Fig.MRI.LabelHandle(i) = uicontrol( 'Style','Text',...
                                        'String',Fig.MRI.Labels{i},...
                                        'HorizontalAlignment','Left',...
                                        'pos',Fig.MRI.LabelPos{i},...
                                        'parent',Fig.MRI.UIhandle);
   	if ~any(ismember(i, [2,3,4]))
        Fig.MRI.InputHandle(i) = uicontrol( 'Style',Fig.MRI.Style{i},...
                                            'String',Fig.MRI.List{i},...
                                            'HorizontalAlignment','Left',...
                                            'pos',[Fig.MRI.InputDim(1)+10,15+Pos*Fig.MRI.InputDim(2)*1.5,Fig.MRI.InputSizes(i),20],...
                                            'Callback',{@MRIparams,i,0},...
                                            'parent',Fig.MRI.UIhandle);
    elseif any(ismember(i, [2,3,4]))
        for n = 1:3
            Fig.MRI.MultiInputH(i,n) = uicontrol( 'Style',Fig.MRI.Style{i},...
                                            'String', num2str(Fig.MRI.List{i}(n)),...
                                            'HorizontalAlignment','Left',...
                                            'pos',[Fig.MRI.InputDim(1)+10+((n-1)*50), 15+Pos*Fig.MRI.InputDim(2)*1.5, Fig.MRI.InputSizes(i), 20],...
                                            'HorizontalAlignment','Left',...
                                            'Callback',{@MRIparams,i,n},...
                                            'parent',Fig.MRI.UIhandle);
        end
    end
end
% set([Fig.MRI.LabelHandle, Fig.MRI.InputHandle], 'BackgroundColor',Fig.Background);


%=============== GRID GUI PANEL
Fig.Grid.BoxPos      = [0.75,0.2,0.2,0.3];
Fig.Grid.InputDim    = [150 20];
Fig.Grid.InputSizes  = [150, 150, 40, 40, 60, 100, 100];
Fig.Grid.Labels      = {'Grid type','Trasnform matrix','Origin (mm)','Rotation','Transparency','Add trajectory','Save transform'};
Fig.Grid.Style       = {'popupmenu','pushbutton','edit','edit','edit','pushbutton','pushbutton'};
Fig.Grid.List        = {{'19mm cylindrical'}, Grid.TformName, Grid.Trans, Grid.RotDeg, Grid.Alpha, 'Add', 'Save'};
Fig.Grid.UIhandle    = uipanel('Title','Grid','FontSize', Fig.UIFontsize,'BackgroundColor',Fig.Background,'Units','normalized','Position',Fig.Grid.BoxPos);
for i = 1:numel(Fig.Grid.Labels)
    Pos = numel(Fig.Grid.Labels)-i;
    Fig.Grid.LabelPos{i} = [20, 10+Pos*Fig.Grid.InputDim(2)*1.5, Fig.Grid.InputDim];
    Fig.Grid.LabelHandle(i) = uicontrol( 'Style','Text',...
                                        'String',Fig.Grid.Labels{i},...
                                        'HorizontalAlignment','Left',...
                                        'pos',Fig.Grid.LabelPos{i},...
                                        'parent',Fig.Grid.UIhandle);
    if ~any(ismember(i, [3,4]))                                
        Fig.Grid.InputHandle(i) = uicontrol( 'Style',Fig.Grid.Style{i},...
                                            'String',Fig.Grid.List{i},...
                                            'HorizontalAlignment','Left',...
                                            'pos',[Fig.Grid.InputDim(1)+10,15+Pos*Fig.Grid.InputDim(2)*1.5,Fig.Grid.InputSizes(i),20],...
                                            'Callback',{@Gridparams,i, []},...
                                            'parent',Fig.Grid.UIhandle);
    elseif any(ismember(i, [3,4]))
        for n = 1:3
            Fig.Grid.MultiInputH(i,n) = uicontrol( 'Style',Fig.Grid.Style{i},...
                                        'String',Fig.Grid.List{i}(n),...
                                        'HorizontalAlignment','Left',...
                                        'pos',[Fig.Grid.InputDim(1)+10+((n-1)*50),15+Pos*Fig.Grid.InputDim(2)*1.5,Fig.Grid.InputSizes(i),20],...
                                        'Callback',{@Gridparams,i,n},...
                                        'parent',Fig.Grid.UIhandle);
        end
    end
end
set([Fig.Grid.LabelHandle,Fig.Grid.InputHandle([1,5])], 'BackgroundColor',Fig.Background);

%=============== MARKER FIT GUI PANEL




UpdatePlots;


end

%% ========================== SUBFUNCTIONS ================================

%============= Load MRI volume
function nii = LoadMRI(NiiFile)
    nii                 = load_nii(NiiFile);                            % Load anatomical volume
    [~, nii.filename]   = fileparts(nii.fileprefix);
    nii.OriginVox     	= nii.hdr.hist.originator(1:3); 
    nii.VoxDim          = nii.hdr.dime.pixdim(2:4);
    nii.DimVox          = nii.hdr.dime.dim(2:4);
    nii.DimMm           = nii.VoxDim.*nii.DimVox;
    nii.OriginMm        = nii.OriginVox.*nii.VoxDim;
    nii.AxLims          = [-nii.OriginMm; nii.DimMm-nii.OriginMm];
    nii.sform           = [nii.hdr.hist.srow_x; nii.hdr.hist.srow_y; nii.hdr.hist.srow_z];
end

%============= Plot slices
function UpdatePlots

global Fig Grid nii FV

    %============= PLOT 3D VIEW
    Grid.SliceIndex = nii.OriginVox+round(Grid.Trans./nii.VoxDim);
    Grid.SliceIndex(Grid.SliceIndex > nii.DimVox) = nii.DimVox(Grid.SliceIndex > nii.DimVox);
    axes(Fig.axh(1));
    for v = 1:3
        switch v                                             
            case 1
             	XCoords = [nii.AxLims(1,1), nii.AxLims(1,1); nii.AxLims(2,1), nii.AxLims(2,1)]';
                YCoords = [nii.AxLims(:,2), nii.AxLims(:,2)];
                ZCoords = repmat(nii.AxLims(1,3), [2,2]);
                CurrentSlice = double(repmat(squeeze(nii.img(:,:,Grid.SliceIndex(3)))',[1,1,3]));
            case 2
            	XCoords = repmat(nii.AxLims(1,1), [2,2]);
                YCoords = [nii.AxLims(1,2), nii.AxLims(1,2); nii.AxLims(2,2), nii.AxLims(2,2)]';
                ZCoords = [nii.AxLims(:,3), nii.AxLims(:,3)];
                CurrentSlice = double(repmat(squeeze(nii.img(Grid.SliceIndex(1),:,:))',[1,1,3]));
            case 3
              	XCoords = [nii.AxLims(1,1), nii.AxLims(1,1); nii.AxLims(2,1), nii.AxLims(2,1)]';
                YCoords = repmat(nii.AxLims(1,2), [2,2]);
                ZCoords = [nii.AxLims(:,3), nii.AxLims(:,3)];
                CurrentSlice = double(repmat(squeeze(nii.img(:,Grid.SliceIndex(2),:))',[1,1,3]));
        end    
        if ~isfield(Fig, 'ph') || numel(Fig.ph) < v
            Fig.ph(v) = surf(XCoords, YCoords, ZCoords,'CData', CurrentSlice/max(CurrentSlice(:)),'FaceColor','texturemap','EdgeColor','k');         % Draw MRI slice to axes
        else
            set(Fig.ph(v), 'xdata', XCoords, 'ydata', YCoords, 'zdata', ZCoords, 'cdata', CurrentSlice/max(CurrentSlice(:)));
        end
        hold on;
    end
    
    %============= PLOT 3D GRID ORIGIN TO SLICE
    if ~isfield(Grid, 'OriginHandle')
        Grid.OriginHandle(1) = plot3(Grid.Trans(1), Grid.Trans(2), nii.AxLims(1,3), '.r', 'markersize', 30);
        Grid.OriginHandle(2) = plot3(nii.AxLims(1,1), Grid.Trans(2), Grid.Trans(3), '.r', 'markersize', 30);
        Grid.OriginHandle(3) = plot3(Grid.Trans(1), nii.AxLims(1,2), Grid.Trans(3), '.r', 'markersize', 30);
    else
        set(Grid.OriginHandle(1), 'xdata', Grid.Trans(1), 'ydata', Grid.Trans(2));
        set(Grid.OriginHandle(2), 'ydata', Grid.Trans(2), 'zdata', Grid.Trans(3));
        set(Grid.OriginHandle(3), 'xdata', Grid.Trans(1), 'zdata', Grid.Trans(3));
    end
    
    %=========== PLOT 3D GRID(S)
    if ~isfield(Grid, 'h')
        for g = 1:2
            Grid.h(g) = patch(FV(g), 'facecolor', Grid.Colors(g,:), 'edgecolor', 'none');     % Plot grid at origin
            hold on;
        end
        Grid.tformHandle =	hgtransform('Parent', Fig.axh(1));
        set(Grid.h, 'facealpha', Grid.Alpha);
        set(Grid.h(2), 'Parent', Grid.tformHandle);
        set(Grid.tformHandle, 'Matrix', Grid.Tform);
        set(Grid.h, 'facealpha', Grid.Alpha);
    end

    if ~isfield(Fig, 'lh')
        view(90, 0);
        Fig.lh = camlight('infinite');
        
        set(gca,'color',[0 0 0])
      	xlabel('X (mm)', 'fontsize', 14);
        ylabel('Y (mm)', 'fontsize', 14);
        zlabel('Z (mm)', 'fontsize', 14);
        axis equal tight;
        grid on;
    end
    

    %============= PLOT SLICE VIEWS
    axes(Fig.axh(2));
    Fig.imh(2) = imagesc(nii.AxLims(:,2)', nii.AxLims(:,1)', squeeze(nii.img(:,:,nii.OriginVox(3))));
    hold on;
    Fig.lineh(2,1) = plot([0 0], ylim, '--w');
    Fig.lineh(2,2) = plot(xlim, [0 0], '--w');
    xlabel('Y (mm)', 'fontsize', 14);
    ylabel('X (mm)', 'fontsize', 14);
    title('Axial', 'fontsize', 16);
    axis equal tight xy;

    axes(Fig.axh(3));
    Fig.imh(3) = imagesc(nii.AxLims(:,2)', nii.AxLims(:,3)', squeeze(nii.img(nii.OriginVox(1),:,:))');
    hold on;
    Fig.lineh(3,1) = plot([0 0], ylim, '--w');
    Fig.lineh(3,2) = plot(xlim, [0 0], '--w');
    xlabel('Y (mm)', 'fontsize', 14);
    ylabel('Z (mm)', 'fontsize', 14);
    title('Sagittal', 'fontsize', 16);
    axis equal tight xy;

    axes(Fig.axh(4));
    Fig.imh(4) = imagesc(nii.AxLims(:,1)', nii.AxLims(:,3)', squeeze(nii.img(:,nii.OriginVox(2),:))');
    hold on;
    Fig.lineh(4,1) = plot([0 0], ylim, '--w');
    Fig.lineh(4,2) = plot(xlim, [0 0], '--w');
    xlabel('X (mm)', 'fontsize', 14);
    ylabel('Z (mm)', 'fontsize', 14);
    title('Coronal', 'fontsize', 16);
    axis equal tight xy;

    colormap gray
end

%========================== Update slice views ============================
function UpdateSlices(XYZ)
global Fig Grid nii
    set(Fig.imh(2), 'cdata', squeeze(nii.img(:,:,XYZ(3))), 'xdata', nii.AxLims(:,2)', 'ydata', nii.AxLims(:,1)');
    set(Fig.imh(3), 'cdata', squeeze(nii.img(XYZ(1),:,:))', 'xdata', nii.AxLims(:,2)', 'ydata', nii.AxLims(:,3)');
    set(Fig.imh(4), 'cdata', squeeze(nii.img(:,XYZ(2),:))', 'xdata', nii.AxLims(:,1)', 'ydata', nii.AxLims(:,3)');

    set(Fig.lineh(2,1), 'ydata', nii.AxLims([1,2],1)');
    set(Fig.lineh(2,2), 'xdata', nii.AxLims([1,2],2)');
 	set(Fig.lineh(3,1), 'ydata', nii.AxLims([1,2],3)');
    set(Fig.lineh(3,2), 'xdata', nii.AxLims([1,2],2)');
 	set(Fig.lineh(4,1), 'ydata', nii.AxLims([1,2],3)');
    set(Fig.lineh(4,2), 'xdata', nii.AxLims([1,2],1)');
    
    for ax = 2:4
        axes(Fig.axh(ax));
        axis equal tight
    end
end

%======================= Update MR volume parameters ======================
function MRIparams(hObj, event, indx, indx2)
global Fig Grid nii

switch indx
    case 1          %=============== LOAD NEW MRI VOLUME
        [file, path]    = uigetfile('*.nii', 'Select MRI to load');
        NiiFile         = fullfile(path, file);
        nii             = LoadMRI(NiiFile);
        nii.Filename    = file;
        set(Fig.MRI.InputHandle(1), 'string', nii.Filename);
     	for n = 1:3
        	set(Fig.MRI.MultiInputH(2,n),'String', num2str(nii.VoxDim(n)));
            set(Fig.MRI.MultiInputH(3,n),'String', num2str(nii.OriginVox(n)));
        end
        UpdateSlices(nii.OriginVox);
        UpdatePlots;
        
    case 2          %=============== RESLICE VOLUME
        
        
    case 3          %=============== CROP/ PAD VOLUME
        
        
    case 4          %=============== ADJUST ORIGIN COORDINATES
        nii.OriginVox(indx2)= str2num(get(hObj,'string'));
        nii.OriginMm        = nii.OriginVox.*nii.VoxDim;
        nii.AxLims          = [-nii.OriginMm; nii.DimMm-nii.OriginMm];
        UpdateSlices(nii.OriginVox);

        
    case 5          %=============== PERMUTE VOLUME
        
        
    case 6          %=============== SAVE VOLUME CHANGES
        
        
end


end

%======================= Update grid parameters ===========================
function Gridparams(hObj, event, indx, indx2)
global Fig Grid nii

switch indx
    case 1     	%=============== CHANGE GRID TYPE
        Grid.TypeIndx = get(hObj, 'value');
        
        
        
    case 2      %=============== LOAD NEW T-FORM
        [file, path]    = uigetfile('*.mat', 'Select trasnform matrix file');
        Grid.TformFile 	= fullfile(path, file);
        load(Grid.TformFile);
        Grid.Tform      = T;
        Grid.RotDeg   	= [];
        Grid.Trans     	= Grid.Tform(1:3,4)';                     	% Translations relative to AC origin
        for n = 1:3
            set(Fig.Grid.MultiInputH(3,n), 'string', num2str(Grid.Trans(n)));
            set(Fig.Grid.MultiInputH(4,n), 'string', num2str(Grid.RotDeg(n)));
        end
        set(Grid.tformHandle, 'Matrix', Grid.Tform);
        
    case 3      %=============== CHANGE ORIGIN
        Grid.Trans(indx2)   = str2num(get(hObj, 'string'));
        Grid.Tform        	= makehgtform('translate',Grid.Trans(1), Grid.Trans(2), Grid.Trans(3), ...
                            'xrotate',Grid.RotRad(1),'yrotate',Grid.RotRad(2),'zrotate',Grid.RotRad(3));
        set(Grid.tformHandle, 'Matrix', Grid.Tform);
        UpdatePlots;
        
    case 4      %=============== CHANGE ORIENTATION
        Grid.RotDeg(indx2)     = str2num(get(hObj, 'string'));
        Grid.RotRad         = Grid.RotDeg/180*pi;
        Grid.Tform        	= makehgtform('translate',Grid.Trans(1), Grid.Trans(2), Grid.Trans(3), ...
                            'xrotate',Grid.RotRad(1),'yrotate',Grid.RotRad(2),'zrotate',Grid.RotRad(3));
        set(Grid.tformHandle, 'Matrix', Grid.Tform);
        UpdatePlots;
        
    case 5     	%=============== CHANGE OPACITY
        Grid.Alpha  = str2num(get(hObj, 'string'));
        set(Grid.h, 'facealpha', Grid.Alpha);
        if isfield(Grid, 'Trajectory')
            set(Grid.Trajectory(1).Handle, 'facealpha', Grid.Alpha);
        end
        
    case 6    	%=============== ADD TRAJECTORY PATH
        Response = inputdlg({'Grid hole coordinate (X)','Grid hole coordinate (Y)','Length (mm)','Diameter (mm)','Color (RGB)'},'Add trajectory path',1,{'0','0','20','0.5','0 0 1'});
        if ~isempty(Response)
            if isfield(Grid, 'Trajectory')
                n = numel(Grid.Trajectory)+1;
            else
                n = 1;
            end
            Grid.Trajectory(n).XY          = [str2num(Response{1}), str2num(Response{2})];
            Grid.Trajectory(n).Length      = str2num(Response{3});
            Grid.Trajectory(n).Diameter    = str2num(Response{4});
            Grid.Trajectory(n).Color       = str2num(Response{5});
            [X,Y,Z] = cylinder(repmat(Grid.Trajectory(n).Diameter,[1,2]), 20);
            X = X+Grid.Trajectory(n).XY(1);
            Y = Y+Grid.Trajectory(n).XY(2);
            Z = Z*-Grid.Trajectory(n).Length;
            Grid.Trajectory(1).Handle(n)  	= surf(X, Y, Z, 'facecolor', Grid.Trajectory(n).Color, 'edgecolor', 'none');
            set(Grid.Trajectory(1).Handle(n), 'Parent', Grid.tformHandle);
            set(Grid.tformHandle, 'Matrix', Grid.Tform);
        end
        
%     case 7      %=============== SAVE TRANSFORM
%         [file, path]        = uiputfile('ManualXform.mat', 'Save trasnform matrix');
%         Grid.TformFile      = fullfile(path, file);
%         [~,Grid.TformName]	= fileparts(Grid.TformFile);
%         T = Grid.Tform;
%         save(Grid.TformFile, 'T');
%         set(Fig.Grid.InputHandle(1), 'string', Grid.TformName);
        
    case 7      %=============== SHOW AXIS-ALIGNED VOLUME SLICE
        Grid.Tform
        [nii.new_img, new_M] = affine(nii.img, Grid.Tform);
        figure;
        imagesc(squeeze(nii.new_img(:,100,:)));
        axis equal tight
        colormap gray
end

end