function rootPath = flRP()
% Determine path to root of the fLoc directory
%
%        rootPath = flRP;
%
% This function MUST reside in the directory at the base of the
% repo directory structure 
%
% Copyright GLU 2025
% test
rootPath = which('flRP');

rootPath = fileparts(rootPath);

return
