function [Status] = ENT_WriteSessionParams(HistoryFile, CurrentParams, DataQuality)

%========================== ENT_WriteSessionParams.m ======================
% This function writes the provided session parameters to the specified 
% spreadsheet file, for the date specified.
%
% INPUTS:
%       HistoryFile:    full path of spreadsheet (.xls/ .csv) containing recording history
%       CurrentParams: 	parameters of the current session in a 1 x (1+N*5) 
%                       cell array (where N is the number of electrodes
%                       used in the session) containing the following cells:
%                           1) Session date 
%                           2) Electrode 1 ID (string)
%                           3) Electrode 1 M-L position (grid holes)
%                           4) Electrode 1 A-P position (grid holes)
%                           5) Electrode 1 depth (mm)
%                           6) Electrode 1 guide tube length (mm)
%                           [optional] 7) Electrode 2 ID (string)
%                           [optional] 8) Electrode 2 M-L position (grid
%                           holes)... etc.
%       DataQuality:    Optional input of a Ch x N matrix containing numerical 
%                       data quality ratings (where Ch is teh numebr of channels
%                       and N is the number of electrodes for the session being
%                       updated). 
%
%
% ELECTRONAV TOOLBOX
% Developed by Aidan Murphy
% ? Copyleft 2014, GNU General Public License
%==========================================================================

%========================== Check inputs
Status = 0;
if nargin == 0
    [file, path] = uigetfile({'*.xls;*.csv'},'Select recording history');
    HistoryFile = fullfile(path, file);
end
if ~exist(HistoryFile,'file')
    error('Session history file %s does not exist!', HistoryFile);
end
if ~iscell(CurrentParams)
    error('Input CurrentParams must be a cell array!');
end
[a,b,HistoryFormat] = fileparts(HistoryFile);

%========================== Load recording history data
SessionParams = ENT_LoadSessionParams(HistoryFile, 'all');     % Load all data currently saved
if ischar(CurrentParams{1})
    CurrentDatestring = CurrentParams{1};
	CurrentParams{1} = datenum(CurrentParams{1})-datenum('30-Dec-1899');
elseif ~ischar(CurrentParams{1})
    CurrentDatestring = datestr(CurrentParams{1}+datenum('30-Dec-1899'));
end
SessionIndx = find(~cellfun(@isempty, strfind({SessionParams.DateString},CurrentDatestring)));
if ~isempty(SessionIndx)
    msg = sprintf('History file %s already contains data for %s. Do you want to overwrite it?', HistoryFile, SessionParams(SessionIndx).DateString);
    Overwrite = questdlg(msg, 'Overwrite data?', 'Yes','No','No');
    if strcmpi(Overwrite, 'No')
     	Status = 0;
        return;
    end
end

%========================== SAVE DATA
if exist('readtable','file')~=0
    try
        T = readtable(HistoryFile);
        T.Date = datetime(T.Date,'ConvertFrom','excel');
        if size(T,2) > size(CurrentParams,2)
            CurrentParams{size(T,2)} = NaN;
            CurrentParams(cellfun(@isempty, CurrentParams)) = {NaN};
        elseif size(T,2) < size(CurrentParams,2)
            T(:, end+1:size(CurrentParams,2)) = NaN;
        end
        T = [T; CurrentParams];                                                                             % Append new data
        writetable(T,HistoryFile);
    catch
        UseXLS = 1;
    end
end
if exist('readtable','file')==0 || UseXLS == 1  %==================== WRITE DATA TO .XLS FILE   

    [num,txt,raw] =  xlsread(HistoryFile,1,'');                 % Read data from Excel file
    for i = 2:size(raw,1) 
        raw{i,1} = raw{i,1}+datenum('30-Dec-1899');             % Convert Excel dates to Matlab dates
    end
    if size(raw,2) > numel(CurrentParams)
        CurrentParams((end+1):size(raw,2)) = deal({nan});       % Pad with NaNs
    elseif size(raw,2) < size(CurrentParams,2)
        raw(:, (end+1):size(CurrentParams,2)) = deal({nan});    
    end
    raw(end+1,:) = CurrentParams;
    [Success, Msg] = xlswrite(HistoryFile, raw, 1);
    if Success ~= 1
        disp(Msg(1).message);
    end
end

if Success ~= 2
    [path, file, format] = fileparts(HistoryFile);
    Matfilename = fullfile(path, [file, '.mat']);
    fprintf('Writing to %s failed! Saving backup to .mat file %s instead.\n', HistoryFile, Matfilename);
%         [Filename, Pathname, Indx] = uiputfile('.csv', 'Save current session to .csv file');  	% Ask user to specify file to save to
    save(Matfilename, 'raw');
end



if strcmpi(HistoryFile(end-2:end), 'csv')       %==================== WRITE DATA TO .CSV FILE               
    formatSpec = '%{dd-MMM-yyyy}D%f%f%f%f%f%C';
    if exist('readtable','file')~=0
        T = readtable(HistoryFile,'Delimiter',',','Format',formatSpec);
        T = [T; CurrentParams];                                                                         % Append new data
    %                 T = cell2table(T,'VariableNames',fieldnames(T));                                      % convert to table
        T.Date.Format = 'dd-MMM-yyyy';                                              
        writetable(T,HistoryFile);                                                     % write table to .csv file
    else
        T = csvread(HistoryFile);
        T = [T; CurrentParams];
        fid = fopen(HistoryFile, 'wt');                                             	 % write table to .csv file
        fprintf(fid, '%s, %s, %s, %s, %s, %s, %s\n', T{1,:});
        for i = 2:size(T,1)
            fprintf(fid, '%d, %d, %d, %f, %f, %d, %s\n', T{i,:});
        end
        fclose(fid);
    end
end

%==================== SAVE DATA QUALITY RATINGS
if exist('DataQuality', 'var')
    if strcmpi(HistoryFormat, '.xls')
        [status, sheets] = xlsfinfo(HistoryFile);
        if numel(sheets) >= 2
            [num,txt,raw] =  xlsread(HistoryFile,sheets{2},'');                         % Read data from Excel file sheet 2
            DateIndx = strfind(num(1,:), CurrentParams{1})+1;                          	% Find column index of current session date
            ElectrodeNames = CurrentParams(2:5:end);
            ElectrodeNames = ElectrodeNames(cellfun(@ischar, ElectrodeNames));    
          	if size(DataQuality, 2) ~= numel(ElectrodeNames)
                error('Columns in DataQuality must match number of electorde IDs in CurrentParams!');
            end
            if isempty(DateIndx)                                                        
                DateIndx = size(num,2);                                                 
                for n = 1:size(DataQuality, 2)                                          % For each electrode in current session...
                    raw{1, DateIndx+n} = CurrentParams{1};                              
                    raw{2, DateIndx+n} = ElectrodeNames{n};                              
                    raw(2+(1:size(DataQuality,1)), DateIndx+n) = num2cell(DataQuality(:,n));                        
                end
            elseif ~isempty(DateIndx)                                                   % If date already exists in spreadsheet...
                if numel(DateIndx) == numel(ElectrodeNames)                             % If number of electrodes hasn't changed...
                    for n = 1:numel(DateIndx)
                        raw(3:size(DataQuality,1), DateIndx+n) = num2cell(DataQuality(:,n)); 
                    end
                end
            end
         	[Success2, Msg2] = xlswrite(HistoryFile, raw, 2);
            if Success2 ~= 1
                disp(Msg);
            end
        end
    end

end 
    
end                         