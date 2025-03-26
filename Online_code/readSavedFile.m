% read data saved by matlab
% 2022-11-18
% Hanlei Li  
function raw = readSavedFile(filename)
    [~,name,ext] = fileparts(filename);
    if strcmpi(ext,'.txt')
        [~,endIndex] = regexp(name,'nbChan-');
        nChan = str2num(name(endIndex+1:endIndex+2));
        fileID = fopen(filename);
%         raw = reshape(fread(fileID,'float32'),nChan,[]);
        raw = reshape(fread(fileID,'double'),nChan,[]);
        fclose(fileID);
    else
        raw = [];
    end
end

