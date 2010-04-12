function stream_vacc_init(blk, varargin)
% Initialize and configure the cross-correlator, which can then be
% processed using an FFT after the final adder to get baseline
% visibilities.
%
% cross_correlator_init(blk, varargin)
%
% blk = The block to configure.
% varargin = {'varname', 'value', ...} pairs
% 
% Valid varnames for this block are:
% acc_len = Number of samples to accumulate
% total_lags = Size of the correlator and subsequent FFT 

% Declare any default values for arguments you might like.
defaults = {...
    'vector_len', 5,...
    'input_bit_width', 18,...
    'input_bin_pt', 14,...
    'samples_out', 3,...
    'output_bit_width', 22,...
    'output_bin_pt', 14,...
    'quantization', 'Truncate',...
    'overflow', 'Wrap',...
    'specify_add', 'off',...
    'add_spec', 'Fabric',...
    'add_delay', 1};
if same_state(blk, 'defaults', defaults, varargin{:}), return, end
check_mask_type(blk, 'stream_vacc');
munge_block(blk, varargin{:});

% Get the necessary mask parameters.
vector_len = get_var('vector_len', 'defaults', defaults, varargin{:});
input_bit_width = get_var('input_bit_width', 'defaults', defaults, varargin{:});
input_bin_pt = get_var('input_bin_pt', 'defaults', defaults, varargin{:});
samples_out = get_var('samples_out', 'defaults', defaults, varargin{:});
output_bit_width = get_var('output_bit_width', 'defaults', defaults, varargin{:});
output_bin_pt = get_var('input_bin_pt', 'defaults', defaults, varargin{:});
quantization = get_var('quantization', 'defaults', defaults, varargin{:});
overflow = get_var('overflow', 'defaults', defaults, varargin{:});
specify_add = get_var('specify_add', 'defaults', defaults, varargin{:});
add_spec = get_var('add_spec', 'defaults', defaults, varargin{:});
add_delay= get_var('add_delay', 'defaults', defaults, varargin{:});

% Remove all lines, will be redrawn later
delete_lines(blk);

x0 = 30; % where we'll start to draw blocks, everything
y0 = 32; % will be relative to this position

width = 30;
height = 16;
port_ysep = 100;
chan_ysep = port_ysep*(2^vector_len);
reuse_block(blk, 'sync', 'built-in/inport',...
    'Position', [x0 y0 x0+width y0+height], 'Port', '1');
for i=0:2^floor(vector_len-samples_out)-1,
    % Draw the input data ports, each one is a concatenated set of
    % 2^samples_out vector points
    reuse_block(blk, ['[', num2str(i*2^samples_out), '-',...
        num2str((i+1)*2^samples_out-1), ']'], 'built-in/inport',...
        'Position', [x0 y0+(i+3)*port_ysep,...
        x0+width y0+(i+3)*port_ysep+height],...
        'Port',  num2str(2+i));
end

if samples_out<vector_len,
    mode = 'Accumulate';
    
elseif vector_len<samples_out,
    mode = 'Stack';
else
    mode = 'Pass through';
end

% Clean blocks and finish up.
%clean_blocks(blk);
fmtstr = sprintf('%d=>%d samples\n%s',...
    2^vector_len, 2^samples_out, mode);
set_param(blk, 'AttributesFormatString', fmtstr);
save_state(blk, 'defaults', defaults, varargin{:});