function cross_correlator_init(blk, varargin)
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
% total_lags = Size of the correlator and subsequent FFT 
% n_inputs = Number of simultanoues inputs, demux factor
% input_bit_width = Bit width of input
% input_bin_pt = Binary point of input
% specify_data_type = Whether to cast the output into a certain type,
%     otherwise, the block will produce outputs of twice the input
%     bit width and twice the binary point
% output_bit_width = If above, use this output bit width
% output_bin_pt = Use this binary point for the output
% quantization = Quantization behaviour
% overflow = Overflow behaviour
% specify_mult = Whether or not a certain multiplier is preferred
% mult_spec = If so what kind?
% specify_add = Same as above but for the adders
% add_spec = ^^
% mult_delay = Pipeline latency of the multiplier
% add_delay = Same but for the adders


% Declare any default values for arguments you might like.
defaults = {...
    'total_lags', 5,...
    'n_inputs', 1,...
    'use_2bit', 'off',...
    'input_bit_width', 8,...
    'input_bin_pt', 7,...
    'specify_data_type', 'off',...
    'output_bit_width', 16,...
    'output_bin_pt', 14,...
    'quantization', 'Truncate',...
    'overflow', 'Wrap',...
    'specify_mult', 'off',...
    'mult_spec', 'Behavioral',...
    'specify_add', 'off',...
    'add_spec', 'Fabric',...
    'mult_delay', 3,...
    'add_delay', 2,...
    'single_output', 'off'};
if same_state(blk, 'defaults', defaults, varargin{:}), return, end
check_mask_type(blk, 'cross_correlator');
munge_block(blk, varargin{:});

% Get the necessary mask parameters.
total_lags = get_var('total_lags', 'defaults', defaults, varargin{:});
n_inputs = get_var('n_inputs', 'defaults', defaults, varargin{:});
if n_inputs < 1, n_inputs = 1; end
use_2bit = get_var('use_2bit', 'defaults', defaults, varargin{:});
input_bit_width = get_var('input_bit_width', 'defaults', defaults, varargin{:});
input_bin_pt = get_var('input_bin_pt', 'defaults', defaults, varargin{:});
specify_data_type = get_var('specify_data_type', 'defaults', defaults, varargin{:});
output_bit_width = get_var('output_bit_width', 'defaults', defaults, varargin{:});
output_bin_pt = get_var('output_bin_pt', 'defaults', defaults, varargin{:});
quantization = get_var('quantization', 'defaults', defaults, varargin{:});
overflow = get_var('overflow', 'defaults', defaults, varargin{:});
specify_mult = get_var('specify_mult', 'defaults', defaults, varargin{:});
mult_spec = get_var('mult_spec', 'defaults', defaults, varargin{:});
specify_add = get_var('specify_add', 'defaults', defaults, varargin{:});
add_spec = get_var('add_spec', 'defaults', defaults, varargin{:});
mult_delay = get_var('mult_delay', 'defaults', defaults, varargin{:});
add_delay = get_var('add_delay', 'defaults', defaults, varargin{:});
single_output = get_var('single_output', 'defaults', defaults, varargin{:});


% Remove all lines, will be redrawn later
delete_lines(blk);

x0 = 30; % where we'll start to draw blocks, everything
y0 = 32; % will be relative to this position

width = 30;
height = 16;
port_ysep = 50;
chan_ysep = port_ysep*(2^n_inputs);
for i=0:2^n_inputs-1,
    % Draw the input data ports
    reuse_block(blk, ['i', num2str(i)], 'built-in/inport',...
        'Position', [x0 y0+(i+3)*port_ysep,...
        x0+width y0+(i+3)*port_ysep+height],...
        'Port',  num2str(2+i));
    reuse_block(blk, ['q', num2str(i)], 'built-in/inport',...
        'Position', [x0 y0+chan_ysep+(i+3)*port_ysep,...
        x0+width y0+chan_ysep+(i+3)*port_ysep+height],...
        'Port', num2str(2+2^n_inputs+i));
    
    % Draw the starting delays
    if total_lags>n_inputs, 
        delay = 2^(total_lags-n_inputs-1);
    else
        delay = 0;
    end
    reuse_block(blk, ['start_delay_q', num2str(i)],...
        'xbsIndex_r4/Delay',...
        'Position', [x0+64 y0+chan_ysep+(i+3)*port_ysep,...
        x0+64+16 y0+chan_ysep+(i+3)*port_ysep+16],...
        'Latency', num2str(delay));
    add_line(blk, ['q', num2str(i), '/1'],...
        ['start_delay_q', num2str(i), '/1']);
end

name = '';
% Setup the lag-elements
for i=-2^(total_lags-1):2^(total_lags-1)-1,
    lastname = name;
    if sign(i)==1,
        name = ['lag+', num2str(i)];
    else
        name = ['lag', num2str(i)];
    end
    reuse_block(blk, name, 'dali_library/single_lag',...
        'Position', [x0+(i+2^(total_lags-1)+1)*128 y0+3*port_ysep-12,...
        x0+(i+2^(total_lags-1)+1)*128+100,...
        y0+chan_ysep+(2^n_inputs+2)*port_ysep+28],...
        'n_inputs', num2str(n_inputs),...
        'specify_mult', specify_mult',...
        'mult_spec', mult_spec,...
        'specify_add', specify_add,...
        'add_spec', add_spec,...
        'mult_delay', num2str(mult_delay),...
        'add_delay', num2str(add_delay),...
        'use_2bit', use_2bit,...
        'shift_q', 'off',...
        'shift_i', 'on');
    if i==-2^(total_lags-1),
        reuse_block(blk, 'blank_lag', 'xbsIndex_r4/Constant',...
            'Position', [x0+64 y0+chan_ysep+(2^n_inputs+3)*port_ysep,...
            x0+64+16 y0+chan_ysep+(2^n_inputs+3)*port_ysep+16],...
            'Arith_Type', 'Unsigned',...
            'Const', '0',...
            'N_bits', '1',...
            'Bin_Pt', '0',...
            'Explicit_Period', 'on',...
            'Period', '1');
        add_line(blk, 'blank_lag/1', [name, '/', num2str(2^(n_inputs+1)+1)]);
        for j=0:2^n_inputs-1,
            add_line(blk, ['i', num2str(j), '/1'],...
                [name, '/', num2str(j+1)]);
            add_line(blk, ['start_delay_q', num2str(j), '/1'],...
                [name, '/', num2str(j+1+2^n_inputs)]);
        end
    else
        for j=1:2^(n_inputs+1)+1,
            add_line(blk, [lastname, '/', num2str(j)],...
                [name, '/', num2str(j)]);
        end
    end
end

% Terminate the ends of the last lag element
for j=0:2^(n_inputs+1)-1,
    reuse_block(blk, ['term', num2str(j)],...
        'built-in/Terminator', 'Position',...
        [x0+128*(2^total_lags+1) y0+(3+j)*port_ysep-12,...
        x0+128*(2^total_lags+1)+16 y0+(3+j)*port_ysep-12+16]);
    add_line(blk, [name, '/', num2str(j+1)],...
        ['term', num2str(j), '/1']);
end

x1 = x0+128*(2^total_lags+2);
y1 = y0+(3+2^n_inputs)*port_ysep;
if strcmp(use_2bit, 'on'),
    lagged_bit_width = n_inputs+5;
    lagged_bin_pt = 0;
else
    lagged_bit_width = n_inputs+input_bit_width*2;
    lagged_bin_pt = input_bin_pt*2;
end
if strcmp(single_output, 'on'),
    n_outputs = 0;
else
    n_outputs = n_inputs+1;
end
% Finally process/accumulate each set of lags such that the block will
% stream similar to the CASPER streaming FFT. This requires the lags to 
% be accumulated total_lags-n_inputs samples at a time. 
reuse_block(blk, 'lag_slice', 'xbsIndex_r4/Slice',...
    'Position', [x1 y1 x1+30 y1+16],...
    'Nbits', num2str(lagged_bit_width*2^total_lags),...
    'Mode', 'Lower Bit Location + Width',...
    'Base0', 'LSB of Input');
add_line(blk, [name, '/', num2str(2^(n_inputs+1)+1)], 'lag_slice/1');
reuse_block(blk, 'uncram', 'gavrt_library/uncram',...
    'Position', [x1+90 y1 x1+120 y1+60],...
    'Num_Slice', num2str(2^(total_lags-n_outputs)),...
    'Slice_Width', num2str(lagged_bit_width*2^(n_outputs)),...
    'Bin_Pt', '0',...
    'Arith_Type', '0');
add_line(blk, 'lag_slice/1', 'uncram/1');
if strcmp(specify_data_type, 'on'),
    stream_bit_width = output_bit_width;
    stream_bin_pt = output_bin_pt;
    stream_quant = quantization;
    stream_overflow = overflow;
else
    stream_bit_width = lagged_bit_width+2^(total_lags-n_inputs-1);
    stream_bin_pt = lagged_bin_pt;
    stream_quant = 'Truncate';
    stream_overflow = 'Wrap';
end
reuse_block(blk, 'sync', 'built-in/inport',...
    'Position', [x1-2*width y1-4*height x1-width y1-3*height], 'Port', '1');
reuse_block(blk, 'stream_vacc', 'dali_library/stream_vacc',...
    'Position', [x1+150 y1 x1+250 y1+60],...
    'Vector_Len', num2str(total_lags),...
    'Input_Bit_Width', num2str(lagged_bit_width),...
    'Input_Bin_Pt', num2str(lagged_bin_pt),...
    'Samples_Out', num2str(n_outputs),...
    'Output_Bit_Width', num2str(stream_bit_width),...
    'Output_Bin_Pt', num2str(stream_bin_pt),...
    'Quantization', stream_quant,...
    'Overflow', stream_overflow,...
    'Specify_Add', specify_add,...
    'Add_Spec', add_spec);
add_line(blk, 'sync/1', 'stream_vacc/1');
for i=1:2^(total_lags-n_outputs),
    add_line(blk, ['uncram/', num2str(i)], ['stream_vacc/', num2str(i+1)]);
end
reuse_block(blk, 'sync_out', 'built-in/outport',...
    'Position', [x1+250+6*width y1-4*height x1+250+7*width y1-3*height], 'Port', '1');
add_line(blk, 'stream_vacc/1', 'sync_out/1');
reuse_block(blk, 'valid', 'built-in/outport',...
    'Position', [x1+250+6*width y1-4*height+120 x1+250+7*width y1-3*height+120], 'Port', '2');
add_line(blk, 'stream_vacc/2', 'valid/1');
for i=0:2^(n_outputs)-1,
    output_name = ['[n+', num2str(i), ']'];
    reuse_block(blk, output_name, 'built-in/outport',...
        'Position', [x1+300 y1+(i+1)*height+160 x1+300+width y1+(i+2)*height+160],...
        'Port',  num2str(3+i));
    add_line(blk, ['stream_vacc/', num2str(i+3)], [output_name, '/1']);
end

% Clean blocks and finish up.
clean_blocks(blk);
if strcmp(use_2bit, 'off'),
    fmtstr = sprintf('%d lags, Demux: %d, Outputs: %d\n%d_%d=>%d_%d, %s, %s\n Mult: %s, Add: %s',...
        2^total_lags, 2^n_inputs, 2^n_outputs, input_bit_width, input_bin_pt,...
        output_bit_width, output_bin_pt, quantization, overflow,...
        get_var('mult_spec', 'defaults', defaults, varargin{:}),...
        get_var('add_spec', 'defaults', defaults, varargin{:}));
else
    fmtstr = sprintf('%d lags, Demux: %d, Outputs: %d\nSpecial 2-bit binary encoding\n Mult: %s, Add: %s',...
        2^total_lags, 2^n_inputs, 2^n_outputs,...
        get_var('mult_spec', 'defaults', defaults, varargin{:}),...
        get_var('add_spec', 'defaults', defaults, varargin{:}));
end
set_param(blk, 'AttributesFormatString', fmtstr);
save_state(blk, 'defaults', defaults, varargin{:});