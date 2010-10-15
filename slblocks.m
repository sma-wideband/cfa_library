function blkStruct = slblocks
%SLBLOCKS Defines the Simulink library block representation
%   for the Xilinx Blockset.

% Copyright (c) 1998 Xilinx Inc. All Rights Reserved.
blkStruct.Name    = ['CFA Blockset'];
blkStruct.OpenFcn = '';
blkStruct.MaskInitialization = '';

blkStruct.MaskDisplay = ['disp(''CFA Blockset'')'];

% Define the library list for the Simulink Library browser.
% Return the name of the library model and the name for it
%
Browser(1).Library = 'cfa_library';
Browser(1).Name    = 'CFA Blockset';
% Browser(2).Library = 'testbench_lib';
% Browser(2).Name    = 'Testbench Blockset';

blkStruct.Browser = Browser;

% End of slblocks.m

