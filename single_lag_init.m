function single_lag_init(blk, varargin)
% Initialize and configure the cross-correlator, which can then be
% processed using an FFT after the final adder to get baseline
% visibilities.
%
% xcorr_init(blk, varargin)
%
% blk = The block to configure.
% varargin = {'varname', 'value', ...} pairs
% 
% Valid varnames for this block are:
% total_lags = Size of the correlator and subsequent FFT 
% n_inputs = Number of simultanoues inputs, demux factor
% input_bit_width = Bit width of input and output
% quantization = Quantization behaviour
% overflow = Overflow behaviour
% specify_mult = Whether or not a certain multiplier is preferred
% mult_spec = If so what kind?
% specify_add = Same as above but for the adders
% add_spec = ^^


% Declare any default values for arguments you might like.
defaults = {...
    'n_inputs', 3,...
    'specify_mult', 'off',...
    'mult_spec', 'Behavioral',...
    'specify_add', 'off',...
    'add_spec', 'Fabric',...
    'mult_delay', 3,...
    'add_delay', 2,...
    'use_2bit', 'off',...
    'shift_q', 'off',...
    'shift_i', 'on'};
if same_state(blk, 'defaults', defaults, varargin{:}), return, end
check_mask_type(blk, 'single_lag');
munge_block(blk, varargin{:});

% Get the necessary mask parameters.
n_inputs = get_var('n_inputs', 'defaults', defaults, varargin{:});
if n_inputs < 0, n_inputs = 0; end
specify_mult = get_var('specify_mult', 'defaults', defaults, varargin{:});
mult_spec = get_var('mult_spec', 'defaults', defaults, varargin{:});
mult_use_embedded = 'off';
mult_use_behavioral = 'on';
if strcmp(specify_mult, 'on'),
    if strcmp(mult_spec, 'Core'),
        mult_use_behavioral = 'off';
    elseif strcmp(mult_spec, 'Embedded'),
        mult_use_behavioral = 'off';
        mult_use_embedded = 'on';
    else 
    end
end
specify_add = get_var('specify_add', 'defaults', defaults, varargin{:});
add_spec = get_var('add_spec', 'defaults', defaults, varargin{:});
if strcmp(specify_add, 'on'),
    add_use_behavioral = 'off';
else
    add_use_behavioral = 'on';
end
mult_delay = get_var('mult_delay', 'defaults', defaults, varargin{:});
add_delay = get_var('add_delay', 'defaults', defaults, varargin{:});
use_2bit = get_var('use_2bit', 'defaults', defaults, varargin{:});
shift_q = get_var('shift_q', 'defaults', defaults, varargin{:});
shift_i = get_var('shift_i', 'defaults', defaults, varargin{:});

% Remove all lines, will be redrawn later
delete_lines(blk);

x0 = 30; % where we'll start to draw blocks, everything
y0 = 32; % will be relative to this position

yshift = 40;
port_ysep = 50;
mult_ysep = 25;
mult_x0 = x0+460;
chan_ysep = 1.5*(16+port_ysep)*(2^n_inputs);
mult_y0 = y0+chan_ysep-((48+mult_ysep)*2^n_inputs)/2;
for i=0:2^n_inputs-1,
    % Draw the inputs/outputs for the first antenna 'i'
    reuse_block(blk, ['i', num2str(i)], 'built-in/inport',...
        'Position', [x0 y0+(i+3)*port_ysep,...
        x0+30 y0+(i+3)*port_ysep+16],...
        'Port',  num2str(1+i));
    reuse_block(blk, ['i', num2str(i-strcmp(shift_i, 'on')), '_out'],...
        'built-in/outport',...
        'Position', [mult_x0/2 y0+(i+3)*port_ysep-yshift,...
        mult_x0/2+30 y0+(i+3)*port_ysep+16-yshift],...
        'Port',  num2str(1+i));
end

for i=0:2^n_inputs-1,
    % Draw the inputs/outputs for the second antenna 'q'
    reuse_block(blk, ['q', num2str(i)], 'built-in/inport',...
        'Position', [x0 y0+chan_ysep+(i+3)*port_ysep,...
        x0+30 y0+chan_ysep+(i+3)*port_ysep+16],...
        'Port', num2str(1+2^n_inputs+i));
    reuse_block(blk, ['q', num2str(i-strcmp(shift_q, 'on')), '_out'],...
        'built-in/outport',...
        'Position', [mult_x0/2 y0+chan_ysep+(i+3)*port_ysep+yshift,...
        mult_x0/2+30 y0+chan_ysep+(i+3)*port_ysep+16+yshift],...
        'Port', num2str(1+2^n_inputs+i));
end

for i=0:2^n_inputs-1,
    % Draw the multipliers
    if strcmp(use_2bit, 'off'),
        reuse_block(blk, ['mult', num2str(i)], 'xbsIndex_r4/Mult',...
            'Position', [mult_x0 mult_y0+i*(48+mult_ysep),...
            mult_x0+48 mult_y0+48+i*(48+mult_ysep)],...
            'Precision', 'Full',...
            'Latency', num2str(mult_delay),...
            'Use_behavioral_HDL', mult_use_behavioral,...
            'Use_embedded', mult_use_embedded);
    else
        reuse_block(blk, ['mult', num2str(i)], 'dali_library/2bit_mult',...
            'Position', [mult_x0 mult_y0+i*(48+mult_ysep),...
            mult_x0+48 mult_y0+48+i*(48+mult_ysep)]);
    end
    add_line(blk, ['i', num2str(i), '/1'], ['mult', num2str(i), '/1']);
    add_line(blk, ['q', num2str(i), '/1'], ['mult', num2str(i), '/2']);
end

add_x0 = mult_x0+260;
% Draw the adder tree, I chose do this instead of use the CASPER adder_tree
% block because the sync input is irrelevant here and because I wanted more
% control over the implementation of the adders
for i=n_inputs-1:-1:0,
    for j=1:2^i,
        add_name = ['add', num2str(2^(i+1)-j-1)];
        reuse_block(blk, add_name,...
            'xbsIndex_r4/AddSub',...
            'Position', [add_x0+(n_inputs-1-i)*260 mult_y0+(j-1)*2*48,...
            add_x0+(n_inputs-1-i)*260+48 mult_y0+(j-1)*2*48+48],...
            'Precision', 'Full',...
            'Pipelined', 'on',...
            'Latency', num2str(add_delay),...
            'Use_behavioral_HDL', add_use_behavioral,...
            'HW_selection', add_spec);
        if i==n_inputs-1,
            add_line(blk, ['mult', num2str(2*j-2), '/1'], [add_name, '/1']);
            add_line(blk, ['mult', num2str(2*j-1), '/1'], [add_name, '/2']);
        else
            add_line(blk,...
                ['add', num2str(2^(i+2)-2*j), '/1'], [add_name, '/1']);
            add_line(blk,...
                ['add', num2str(2^(i+2)-2*j-1), '/1'], [add_name, '/2']);
        end
    end
end

% Connect all outputs appropriately
choice = [2^n_inputs-1 -1];
delays_i = circshift([zeros(1,2^n_inputs)'; ones(1,2^n_inputs)'],...
    -strcmp(shift_i, 'on'));
map_i = [0:2^n_inputs-2 choice(1+strcmp(shift_i, 'on'))];
delays_q = circshift([zeros(1,2^n_inputs)'; ones(1,2^n_inputs)'],...
    -strcmp(shift_q, 'on'));
map_q = [0:2^n_inputs-2 choice(1+strcmp(shift_q, 'on'))];
for i=1:2^n_inputs,
    % Set delays and connect to outputs for i
    reuse_block(blk, ['delay_i', num2str(i-1)], 'xbsIndex_r4/Delay',...
        'Position', [mult_x0/3 y0+(i+2)*port_ysep-yshift,...
        mult_x0/3+16 y0+(i+2)*port_ysep-yshift+16],...
        'Latency', num2str(delays_i(i)));
    add_line(blk, ['i', num2str(i-1), '/1'],...
        ['delay_i', num2str(i-1), '/1']);
    add_line(blk, ['delay_i', num2str(i-1), '/1'],...
        ['i', num2str(map_i(i)), '_out/1']);
    
    % Set delays and connect to outputs for q
    reuse_block(blk, ['delay_q', num2str(i-1)], 'xbsIndex_r4/Delay',...
        'Position', [mult_x0/3 y0+(i+2)*port_ysep+chan_ysep+yshift,...
        mult_x0/3+16 y0+(i+2)*port_ysep+chan_ysep+yshift+16],...
        'Latency', num2str(delays_q(i)));
    add_line(blk, ['q', num2str(i-1), '/1'],...
        ['delay_q', num2str(i-1), '/1']);
    add_line(blk, ['delay_q', num2str(i-1), '/1'],...
        ['q', num2str(map_q(i)), '_out/1']);
end


% Concatenate the lag_in port with the output of the adder tree and then 
% connect that to the lag_out port
reuse_block(blk, 'lag_in', 'built-in/inport',...
    'Position', [add_x0+(n_inputs-1)*260 mult_y0*1.3,...
    add_x0+(n_inputs-1)*260+30 mult_y0*1.3+16],...
    'Port', num2str(2^(n_inputs+1)+1));
reuse_block(blk, 'lag_cat', 'xbsIndex_r4/Concat',...
    'Position', [add_x0+(n_inputs-1)*260+200 mult_y0*1.2,...
    add_x0+(n_inputs-1)*260+200+16 mult_y0*1.2+48]);
add_line(blk, 'lag_in/1', 'lag_cat/1');
reuse_block(blk, 'reinterp', 'xbsIndex_r4/Reinterpret',...
    'Position', [add_x0+(n_inputs-1)*260+82 mult_y0+24,...
    add_x0+(n_inputs-1)*260+98 mult_y0+34],...
    'Force_Arith_type', 'on',...
    'Arith_type', 'Unsigned',...
    'Force_bin_pt', 'on',...
    'bin_pt', '0');
reuse_block(blk, 'lag_out', 'built-in/outport',...
    'Position', [add_x0+n_inputs*260 mult_y0,...
    add_x0+n_inputs*260+30 mult_y0+16],...
    'Port', num2str(2^(n_inputs+1)+1));
if n_inputs==0,
    add_line(blk, 'mult0/1', 'reinterp/1');
else
    add_line(blk, 'add0/1', 'reinterp/1');
end
add_line(blk, 'reinterp/1', 'lag_cat/2');
add_line(blk, 'lag_cat/1', 'lag_out/1');

% Clean blocks and finish up.
clean_blocks(blk);
fmtstr = sprintf('Use 2-bit: %s, Demux: %d,\nMult: %s,\nAdd: %s',...
    use_2bit, 2^n_inputs,...
    get_var('mult_spec', 'defaults', defaults, varargin{:}),...
    get_var('add_spec', 'defaults', defaults, varargin{:}));
set_param(blk, 'AttributesFormatString', fmtstr);
save_state(blk, 'defaults', defaults, varargin{:});