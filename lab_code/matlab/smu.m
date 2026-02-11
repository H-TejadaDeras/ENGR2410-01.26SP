
classdef smu < handle
    properties
        port
        dev
        connected

        meas_voltage_gain
        meas_voltage_offset

        src_voltage_gains
        src_voltage_offsets

        src_current_gains
        src_current_offsets

        meas_current_gains
        meas_current_offsets
    end
    properties (Constant)
        VREF = 2.5
        DIVIDER1 = 5. / 2.
        DIVIDER2 = 10.
        RESISTORS = [ 316., 10E3, 316E3, 10E6 ];
        CURRENT_RANGES = [ 1. / smu.RESISTORS(1), 1. / smu.RESISTORS(2), 1. / smu.RESISTORS(3), 1. / smu.RESISTORS(4) ];

        VOLTAGE = 0
        CURRENT = 1

        nominal_meas_voltage_gain = [ smu.DIVIDER2 * smu.VREF / smu.DIVIDER1 / 2 ^ 17, ...
                                      smu.DIVIDER2 * smu.VREF / smu.DIVIDER1 / 2 ^ 17 ];
        nominal_meas_voltage_offset = [ 0, 0 ];

        nominal_src_voltage_gains = [ 2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2, ...
                                      2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2, ...
                                      2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2, ...
                                      2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2; ...
                                      2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2, ...
                                      2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2, ...
                                      2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2, ...
                                      2 ^ 16 * smu.DIVIDER1 / smu.VREF / smu.DIVIDER2 ];
        nominal_src_voltage_offsets = [ 0, 0, 0, 0; 0, 0, 0, 0 ];

        nominal_src_current_gains = [ smu.RESISTORS(1) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF, ...
                                      smu.RESISTORS(2) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF, ...
                                      smu.RESISTORS(3) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF, ...
                                      smu.RESISTORS(4) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF; ...
                                      smu.RESISTORS(1) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF, ...
                                      smu.RESISTORS(2) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF, ...
                                      smu.RESISTORS(3) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF, ...
                                      smu.RESISTORS(4) * smu.DIVIDER1 * 2 ^ 16 / smu.VREF ];
        nominal_src_current_offsets = [0, 0, 0, 0; 0, 0, 0, 0];

        nominal_meas_current_gains = [ smu.VREF / smu.DIVIDER1 / smu.RESISTORS(1) / 2 ^ 17, ...
                                       smu.VREF / smu.DIVIDER1 / smu.RESISTORS(2) / 2 ^ 17, ...
                                       smu.VREF / smu.DIVIDER1 / smu.RESISTORS(3) / 2 ^ 17, ...
                                       smu.VREF / smu.DIVIDER1 / smu.RESISTORS(4) / 2 ^ 17; ...
                                       smu.VREF / smu.DIVIDER1 / smu.RESISTORS(1) / 2 ^ 17, ...
                                       smu.VREF / smu.DIVIDER1 / smu.RESISTORS(2) / 2 ^ 17, ...
                                       smu.VREF / smu.DIVIDER1 / smu.RESISTORS(3) / 2 ^ 17, ...
                                       smu.VREF / smu.DIVIDER1 / smu.RESISTORS(4) / 2 ^ 17 ];
        nominal_meas_current_offsets = [ 0, 0, 0, 0; 0, 0, 0, 0 ];

        FCY = 16e6
        TCY = 62.5e-9

        timer_multipliers = [ smu.TCY, 8. * smu.TCY, 64. * smu.TCY, 256. * smu.TCY ];
    end
    methods
        function obj = smu(varargin)
            obj.connected = false;

            obj.meas_voltage_gain = smu.nominal_meas_voltage_gain;
            obj.meas_voltage_offset = smu.nominal_meas_voltage_offset;

            obj.src_voltage_gains = smu.nominal_src_voltage_gains;
            obj.src_voltage_offsets = smu.nominal_src_voltage_offsets;

            obj.src_current_gains = smu.nominal_src_current_gains;
            obj.src_current_offsets = smu.nominal_src_current_offsets;

            obj.meas_current_gains = smu.nominal_meas_current_gains;
            obj.meas_current_offsets = smu.nominal_meas_current_offsets;

            if nargin == 0
                com_ports = serialportlist('available');

                smu_ids = { 'VID_6666&PID_CDC2' };

                key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB\';
                [~, vals] = dos(['REG QUERY ', key, ' /s /f "FriendlyName"']);
                vals = textscan(vals, '%s', 'delimiter', '\t');
                vals = cat(1, vals{:});

                smus = {};
                for i = 1:length(vals)
                    for j = 1:length(smu_ids)
                        if contains(vals{i}, smu_ids{j})
                            ans = extractBetween(vals{i + 1}, '(', ')');
                            smus{end + 1} = ans{1};
                        end
                    end
                end

                port = '';
                for i = 1:length(com_ports)
                    for j = 1:length(smus)
                        if strcmp(com_ports(i), smus{j})
                            port = com_ports(i);
                        end
                    end
                end
                obj.port = port;
            else
                obj.port = varargin{1};
            end
            try
                obj.dev = serialport(obj.port, 115200);
                configureTerminator(obj.dev, 'CR/LF', 'CR');
                obj.connected = true;
                fprintf('Connected to %s...\n', obj.port);
            catch ME
                fprintf('An error occurred: %s\n', ME.message);
            end

            if ~obj.connected
                return
            end

            obj.read_calibration_values();

            % Enable +/-12V power supplies.
            obj.set_ena12V(1);

            % Set both channels initially to SI/MV mode in the 100nA range.
            obj.smu_set_source_function(1, 'CURRENT');
            obj.smu_set_measure_function(1, 'VOLTAGE');
            obj.smu_set_current_range(1, 3);
            obj.smu_set_source_function(2, 'CURRENT');
            obj.smu_set_measure_function(2, 'VOLTAGE');
            obj.smu_set_current_range(2, 3);

            % Set both channels source values to 0A initially.
            obj.source_current(1, 0);
            obj.source_current(2, 0);

            % Enable both channels
            obj.smu_set_ena(1, 1);
            obj.smu_set_ena(2, 1);
        end

        function toggle_led1(obj)
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'UI:LED1 TOGGLE');
        end

        function set_led1(obj, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['UI:LED1 ', dec2hex(val)]);
        end

        function ret = get_led1(obj)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'UI:LED1?');
            ret = hex2dec(readline(obj.dev));
        end

        function toggle_led2(obj)
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'UI:LED2 TOGGLE');
        end

        function set_led2(obj, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['UI:LED2 ', dec2hex(val)]);
        end

        function ret = get_led2(obj)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'UI:LED2?');
            ret = hex2dec(readline(obj.dev));
        end

        function toggle_led3(obj)
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'UI:LED3 TOGGLE');
        end

        function set_led3(obj, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['UI:LED3 ', dec2hex(val)]);
        end

        function ret = get_led3(obj)
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'UI:LED3?');
            ret = hex2dec(readline(obj.dev));
        end

        function ret = read_sw1(obj)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'UI:SW1?');
            ret = hex2dec(readline(obj.dev));
        end

        function toggle_ena12V(obj)
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'PWR:ENA12V TOGGLE');
        end

        function set_ena12V(obj, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['PWR:ENA12V ', dec2hex(val)]);
        end

        function ret = get_ena12V(obj)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'PWR:ENA12V?');
            ret = hex2dec(readline(obj.dev));
        end

        function ret = smu_get_both_(obj)
            ret = NaN;
            if ~obj.connected
                return
            end

            writeline(obj.dev, 'SMU:BOTH?');
            resp = readline(obj.dev);
            str_vals = split(resp, ',');
            vals = zeros(1, length(str_vals));
            for i = 1:length(str_vals)
                vals(i) = hex2dec(str_vals(i));
            end

            ch1_mode = vals(1);
            ch1_src_val = vals(2) - vals(3);
            ch1_meas_val = vals(5) * 65536 + vals(4)
            if ch1_meas_val >= 2147483648
                ch1_meas_val = ch1_meas_val - 4294967296;
            end

            ch2_mode = vals(6);
            ch2_src_val = vals(7) - vals(8);
            ch2_meas_val = vals(10) * 65536 + vals(9);
            if ch2_meas_val >= 2147483648 
                ch2_meas_val = ch2_meas_val - 4294967296;
            end

            ret = [ch1_mode, ch1_src_val, ch1_meas_val, ch2_mode, ch2_src_val, ch2_meas_val];
        end

        function ret = smu_get_ch_(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), '?']);
            resp = readline(obj.dev);
            str_vals = split(resp, ',');
            vals = zeros(1, length(str_vals));
            for i = 1:length(str_vals)
                vals(i) = hex2dec(str_vals(i));
            end

            mode = vals(1);
            src_val = vals(2) - vals(3);
            meas_val = vals(5) * 65536 + vals(4);
            if meas_val >= 2147483648
                meas_val = meas_val - 4294967296;
            end

            ret = [mode, src_val, meas_val];
        end

        function smu_toggle_ena(obj, channel)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':ENA TOGGLE']);
        end

        function smu_set_ena(obj, channel, val)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':ENA ', dec2hex(val)]);
        end

        function ret = smu_get_ena(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':ENA?']);
            ret = hex2dec(readline(obj.dev));
        end

        function smu_set_current_range(obj, channel, val)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':RANGE ', dec2hex(val)]);
        end

        function ret = smu_get_current_range(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':RANGE?']);
            ret = hex2dec(readline(obj.dev));
        end

        function smu_set_source_function(obj, channel, val)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            if strcmp(val, 'CURRENT') || strcmp(val, 'VOLTAGE')
                writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':SOURCE:FUNCTION ', val]);
            else
                writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':SOURCE:FUNCTION ', dec2hex(val)]);
            end
        end

        function ret = smu_get_source_function(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':SOURCE:FUNCTION?']);
            ret = readline(obj.dev);
        end

        function smu_set_source_value(obj, channel, mode, val)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            if ~(-65535 <= val && val <= 65535)
                return
            end

            pos = uint16(0.5 * (65536 + val));
            neg = uint16(0.5 * (65536 - val));
            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':SOURCE:VALUE ', dec2hex(mode), ',', dec2hex(pos), ',', dec2hex(neg)]);
        end

        function ret = smu_get_source_value(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':SOURCE:VALUE?']);
            resp = readline(obj.dev);
            str_vals = split(resp, ',');
            vals = zeros(1, length(str_vals));
            for i = 1:length(str_vals)
                vals(i) = hex2dec(str_vals(i));
            end

            ret = [vals(1), vals(2) - vals(3)];
        end

        function smu_set_measure_function(obj, channel, val)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            if strcmp(val, 'CURRENT') || strcmp(val, 'VOLTAGE')
                writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':MEASURE:FUNCTION ', val]);
            else
                writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':MEASURE:FUNCTION ', dec2hex(val)]);
            end
        end

        function ret = smu_get_measure_function(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':MEASURE:FUNCTION?']);
            ret = readline(obj.dev);
        end

        function ret = smu_get_measure_value(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            writeline(obj.dev, ['SMU:CH', dec2hex(channel), ':MEASURE:VALUE?']);
            resp = readline(obj.dev);
            str_vals = split(resp, ',');
            vals = zeros(1, length(str_vals));
            for i = 1:length(str_vals)
                vals(i) = hex2dec(str_vals(i));
            end

            val = vals(3) * 65536 + vals(2);
            if val >= 2147483648
                val = val - 4294967296;
            end
            ret = [vals(1), val];
        end

        function dac10_set_dac1(obj, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DAC10:DAC1 ', dec2hex(val)]);
        end

        function ret = dac10_get_dac1(obj)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'DAC10:DAC1?');
            ret = hex2dec(readline(obj.dev));
        end

        function dac10_set_dac2(obj, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DAC10:DAC2 ', dec2hex(val)]);
        end

        function ret = dac10_get_dac2(obj)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, 'DAC10:DAC2?');
            ret = hex2dec(readline(obj.dev));
        end

        function dac10_set_diff(obj, val)
            if ~obj.connected
                return
            end

            if ~(-1023 <= val && val <= 1023)
                return
            end

            if val < 0
               val = val + 65536;
            end
            writeline(obj.dev, ['DAC10:DIFF ', dec2hex(val)]);
        end

        function ret = dac10_get_diff(obj)
            ret = NaN;
            if ~obj.connected
                return
            end

            writeline(obj.dev, 'DAC10:DIFF?');
            val = hex2dec(readline(obj.dev));
            if val >= 32768
                val = val - 65536;
            end
            ret = val;
        end

        function digout_set_mode(obj, pin, mode)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:MODE ', dec2hex(pin), ',', dec2hex(mode)]);
        end

        function ret = digout_get_mode(obj, pin)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:MODE? ', dec2hex(pin)]);
            ret = hex2dec(readline(obj.dev));
        end

        function digout_set(obj, pin)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:SET ', dec2hex(pin)]);
        end

        function digout_clear(obj, pin)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:CLEAR ', dec2hex(pin)]);
        end

        function digout_toggle(obj, pin)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:TOGGLE ', dec2hex(pin)]);
        end

        function digout_write(obj, pin, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:WRITE ', dec2hex(pin), ',', dec2hex(val)]);
        end

        function ret = digout_read(obj, pin)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:READ ', dec2hex(pin)]);
            ret = hex2dec(readline(obj.dev));
        end

        function digout_set_od(obj, pin, val)
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:OD ', dec2hex(pin), ',', dec2hex(val)]);
        end

        function ret = digout_get_od(obj, pin)
            ret = NaN;
            if ~obj.connected
                return
            end
            writeline(obj.dev, ['DIGOUT:OD? ', dec2hex(pin)]);
            ret = hex2dec(readline(obj.dev));
        end

        function digout_set_freq(obj, pin, freq)
            if ~obj.connected
                return
            end

            val = smu.FCY / freq - 1.;
            if val >= 65535
                val = 65535;
            end
            writeline(obj.dev, ['DIGOUT:PERIOD ', dec2hex(pin), ',', dec2hex(uint16(val))]);
        end

        function ret = digout_get_freq(obj, pin)
            ret = NaN;
            if ~obj.connected
                return
            end

            writeline(obj.dev, ['DIGOUT:PERIOD? ', dec2hex(pin)]);
            val = hex2dec(readline(obj.dev));
            ret = smu.FCY / (val + 1.);
        end

        function digout_set_duty(obj, pin, duty)
            if ~obj.connected
                return
            end

            val = 65536 * duty;
            if val >= 65535
                val = 65535;
            end
            writeline(obj.dev, ['DIGOUT:DUTY ', dec2hex(pin), ',', dec2hex(uint16(val))]);
        end

        function ret = digout_get_duty(obj, pin)
            ret = NaN;
            if ~obj.connected
                return
            end

            writeline(obj.dev, ['DIGOUT:DUTY? ', dec2hex(pin)]);
            val = hex2dec(readline(obj.dev));
            ret = val / 65536.;
        end

        function digout_set_width(obj, pin, width)
            if ~obj.connected
                return
            end

            val = smu.FCY * width + 0.5;
            if val <= 1
                val = 1;
            end
            if val >= 65535
                val = 65535;
            end
            writeline(obj.dev, ['DIGOUT:WIDTH ', dec2hex(pin), ',', dec2hex(uint16(val))]);
        end

        function ret = digout_get_width(obj, pin)
            ret = NaN;
            if ~obj.connected
                return
            end

            writeline(obj.dev, ['DIGOUT:WIDTH? ', dec2hex(pin)]);
            val = hex2dec(readline(obj.dev));
            ret = val * smu.TCY;
        end

        function digout_set_period(obj, period)
            if ~obj.connected
                return
            end

            if period > 256. * 65536. * smu.TCY
                return
            elseif period > 64. * 65536. * smu.TCY
                T1CON = 0x0030;
                PR1 = uint16(period * (smu.FCY / 256.)) - 1;
            elseif period > 8. * 65536. * smu.TCY
                T1CON = 0x0020;
                PR1 = uint16(period * (smu.FCY / 64.)) - 1;
            elseif period > 65536. * smu.TCY
                T1CON = 0x0010;
                PR1 = uint16(period * (smu.FCY / 8.)) - 1;
            elseif period >= 8. * smu.TCY
                T1CON = 0x0000;
                PR1 = uint16(period * smu.FCY) - 1;
            else
                return
            end

            writeline(obj.dev, ['DIGOUT:T1PERIOD ', dec2hex(PR1), ',', dec2hex(T1CON)]);
        end

        function ret = digout_get_period(obj)
            ret = NaN;
            if ~obj.connected
                return
            end

            writeline(obj.dev, 'DIGOUT:T1PERIOD?');
            resp = readline(obj.dev);
            str_vals = split(resp, ',');
            vals = zeros(1, length(str_vals));
            for i = 1:length(str_vals)
                vals(i) = hex2dec(str_vals(i));
            end
            PR1 = vals(1);
            T1CON = uint16(vals(2));
            prescalar = idivide(bitand(T1CON, uint16(0x0030)), 16);
            ret = smu.timer_multipliers(prescalar + 1) * (PR1 + 1.);
        end

        function ret = flash_read(obj, address, num_bytes)
            ret = NaN;
            if ~obj.connected
                return
            end

            address_high = uint16(idivide(address, 65536));
            address_low = uint16(bitand(uint32(address), uint32(0xFFFF)));
            writeline(obj.dev, ['FLASH:READ ', dec2hex(address_high), ',', dec2hex(address_low), ',', dec2hex(num_bytes)]);
            resp = readline(obj.dev);
            str_vals = split(resp, ',');
            vals = zeros(1, length(str_vals));
            for i = 1:length(str_vals)
                vals(i) = hex2dec(str_vals(i));
            end
            ret = vals;
        end

        function set_current_range(obj, channel, value)
            obj.smu_set_current_range(channel, value);
        end

        function ret = get_current_range(obj, channel)
            ret = obj.smu_get_current_range(channel);
        end

        function set_source_function(obj, channel, funct)
            obj.smu_set_source_function(channel, funct);
        end

        function ret = get_source_function(obj, channel)
            ret = obj.smu_get_source_function(channel);
        end

        function set_source_value(obj, channel, value)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            resp = obj.smu_get_source_value(channel);
            mode = uint8(resp(1));
            old_value = resp(2);
            if bitand(mode, uint8(0x08)) ~= 0
                source_function = 'CURRENT';
            else
                source_function = 'VOLTAGE';
            end
            if strcmp(source_function, 'CURRENT')
                if abs(value) > smu.CURRENT_RANGES(1)
                    fprint('WARNING: Specified current for channel %d exceeds maximum of ±3.165mA.\n', channel);
                    return
                elseif abs(value) > smu.CURRENT_RANGES(2)
                    current_range = 0;
                elseif abs(value) > smu.CURRENT_RANGES(3)
                    current_range = 1;
                elseif abs(value) > smu.CURRENT_RANGES(4)
                    current_range = 2;
                else
                    current_range = 3;
                end

                new_value = round(value * obj.src_current_gains(channel, current_range + 1) + obj.src_current_offsets(channel, current_range + 1));

                if abs(new_value) > 65535
                    if current_range > 0
                        current_range = current_range - 1;
                        new_value = round(value * obj.src_current_gains(channel, current_range + 1) + obj.src_current_offsets(channel, current_range + 1));
                    elseif new_value > 0
                        new_value = 65535;
                    else
                        new_value = -65535;
                    end
                end

                mode = bitor(bitand(mode, uint8(0x7C)), uint8(current_range));
                obj.smu_set_source_value(channel, mode, new_value);
            else
                if abs(value) > 10.
                    fprint('WARNING: Specified voltage for channel %d exceeds maximum of ±10V.\n', channel);
                    return
                end
                current_range = bitand(mode, uint8(0x03));
                new_value = round(value * obj.src_voltage_gains(channel, current_range + 1) + obj.src_voltage_offsets(channel, current_range + 1));
                obj.smu_set_source_value(channel, mode, new_value);
            end
        end

        function ret = get_source_value(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            resp = obj.smu_get_source_value(channel);
            mode = uint8(resp(1));
            value = resp(2);
            current_range = bitand(mode, uint8(0x03));
            if bitand(mode, 0x08) ~= 0
                source_function = 'CURRENT';
            else
                source_function = 'VOLTAGE';
            end
            if strcmp(source_function, 'CURRENT')
                ret = {(value - obj.src_current_offsets(channel, current_range + 1)) / obj.src_current_gains(channel, current_range + 1), source_function};
            else
                ret = {(value - obj.src_voltage_offsets(channel, current_range + 1)) / obj.src_voltage_gains(channel, current_range + 1), source_function};
            end
        end

        function set_measure_function(obj, channel, funct)
            obj.smu_set_measure_function(channel, funct);
        end

        function ret = get_measure_function(obj, channel)
            ret = obj.smu_get_measure_function(channel);
        end

        function ret = get_measure_value(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            resp = obj.smu_get_measure_value(channel);
            mode = uint8(resp(1));
            value = resp(2);
            current_range = bitand(mode, uint8(0x03));
            if bitand(mode, uint8(0x04)) ~= 0
                measure_function = 'VOLTAGE';
            else
                measure_function = 'CURRENT';
            end
            if strcmp(measure_function, 'CURRENT')
                ret = {obj.meas_current_gains(channel, current_range + 1) * (value + obj.meas_current_offsets(channel, current_range + 1)), measure_function};
            else
                ret = {obj.meas_voltage_gain(channel) * (value + obj.meas_voltage_offset(channel)), measure_function};
            end
        end

        function source_current(obj, channel, current)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            if abs(current) > smu.CURRENT_RANGES(1)
                fprint('WARNING: Specified current for channel %d exceeds maximum of ±3.165mA.\n', channel);
                return
            elseif abs(current) > smu.CURRENT_RANGES(2)
                current_range = 0;
            elseif abs(current) > smu.CURRENT_RANGES(3)
                current_range = 1;
            elseif abs(current) > smu.CURRENT_RANGES(4)
                current_range = 2;
            else
                current_range = 3;
            end

            value = round(current * obj.src_current_gains(channel, current_range + 1) + obj.src_current_offsets(channel, current_range + 1));

            if abs(value) > 65535
                if current_range > 0
                    current_range = current_range - 1;
                    value = round(current * obj.src_current_gains(channel, current_range + 1) + obj.src_current_offsets(channel, current_range + 1));
                elseif value > 0
                    value = 65535;
                else
                    value = -65535;
                end
            end

            resp = obj.smu_get_source_value(channel);
            mode = uint8(resp(1));
            old_source_val = resp(2);
            mode = bitor(bitor(bitand(mode, uint8(0x74)), uint8(0x08)), uint8(current_range));
            obj.smu_set_source_value(channel, mode, value);
        end

        function source_voltage(obj, channel, voltage)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            if abs(voltage) > 10.
                fprint('WARNING: Specified voltage for channel %d exceeds maximum of ±10V.\n', channel);
                return
            end

            resp = obj.smu_get_source_value(channel);
            mode = uint8(resp(1));
            old_source_value = resp(2);
            current_range = bitand(mode, uint8(0x03));
            mode = bitand(mode, uint8(0x77));
            value = round(voltage * obj.src_voltage_gains(channel, current_range + 1) + obj.src_voltage_offsets(channel, current_range + 1));
            obj.smu_set_source_value(channel, mode, value);
        end

        function ret = measure_current(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            resp = obj.smu_get_measure_value(channel);
            mode = uint8(resp(1));
            value = resp(2);

            % If the channel measure function is voltage, set it to current.
            if bitand(mode, uint8(0x04)) ~= 0
                obj.smu_set_measure_function(channel, 'CURRENT');
                pause(0.005);
                resp = obj.smu_get_measure_value(channel);
                mode = uint8(resp(1));
                value = resp(2);
            end

            current_range = bitand(mode, uint8(0x03));
            ret = obj.meas_current_gains(channel, current_range + 1) * (value + obj.meas_current_offsets(channel, current_range + 1));
        end

        function ret = measure_voltage(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            resp = obj.smu_get_measure_value(channel);
            mode = uint8(resp(1));
            value = resp(2);

            % If the channel mesure function is current, set it to voltage.
            if bitand(mode, uint8(0x04)) == 0
                obj.smu_set_measure_function(channel, 'VOLTAGE');
                pause(0.005);
                resp = obj.smu_get_measure_value(channel);
                mode = uint8(resp(1));
                value = resp(2);
            end

            ret = obj.meas_voltage_gain(channel) * (value + obj.meas_voltage_offset(channel));
        end

        function autorange_once(obj, channel)
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            resp = obj.smu_get_ch(channel);
            orig_current_range = resp{1};
            src_function = resp{2};
            orig_src_val = resp{3};
            orig_meas_function = resp{4};
            meas_val = resp{5};

            if strcmp(src_function, 'CURRENT')
                return
            end

            if strcmp(orig_meas_function, 'VOLTAGE')
                obj.smu_set_measure_function(channel, 'CURRENT');
            end

            i = 0;
            done = false;
            while ~done && i < 4
                pause(0.005);
                resp = obj.smu_get_ch(channel);
                current_range = resp{1};
                src_function = resp{2};
                src_val = resp{3};
                meas_function = resp{4};
                meas_val = resp{5};
                if current_range > 0 && abs(meas_val) > 0.97 * smu.CURRENT_RANGES(current_range + 1)
                    current_range = current_range - 1;
                elseif current_range < 3 && abs(meas_val) < 0.95 * smu.CURRENT_RANGES(current_range + 2)
                    current_range = current_range + 1;
                else
                    done = true;
                end
                obj.smu_set_current_range(channel, current_range);
                i = i + 1;
            end

            if strcmp(orig_meas_function, 'VOLTAGE')
                obj.smu_set_measure_function(channel, 'VOLTAGE');
            end

            if current_range ~= orig_current_range
                obj.source_voltage(channel, orig_src_val);
            end
        end

        function ret = smu_get_ch(obj, channel)
            ret = NaN;
            if ~obj.connected
                return
            end

            if channel ~= 1 && channel ~= 2
                fprintf('WARNING: Channel value must be either 1 or 2.\n');
                return
            end

            resp = obj.smu_get_ch_(channel);
            mode = uint8(resp(1));
            src_dac_val = resp(2);
            meas_adc_val = resp(3);
            current_range = bitand(mode, uint8(0x03));
            if bitand(mode, uint8(0x08)) ~= 0
                src_function = 'CURRENT';
            else
                src_function = 'VOLTAGE';
            end
            if strcmp(src_function, 'CURRENT')
                src_val = (src_dac_val - obj.src_current_offsets(channel, current_range + 1)) / obj.src_current_gains(channel, current_range + 1);
            else
                src_val = (src_dac_val - obj.src_voltage_offsets(channel, current_range + 1)) / obj.src_voltage_gains(channel, current_range + 1);
            end
            if bitand(mode, uint8(0x04)) ~= 0
                meas_function = 'VOLTAGE';
            else
                meas_function = 'CURRENT';
            end
            if strcmp(meas_function, 'CURRENT')
                meas_val = obj.meas_current_gains(channel, current_range + 1) * (meas_adc_val + obj.meas_current_offsets(channel, current_range + 1));
            else
                meas_val = obj.meas_voltage_gain(channel) * (meas_adc_val + obj.meas_voltage_offset(channel));
            end

            ret = {current_range, src_function, src_val, meas_function, meas_val};
        end

        function ret = smu_get_both(obj)
            ret = NaN;
            if ~obj.connected
                return
            end

            resp = obj.smu_get_both_();

            ch1_mode = uint8(resp(1));
            ch1_src_dac_val = resp(2);
            ch1_meas_adc_val = resp(3);

            ch1_current_range = bitand(ch1_mode, uint8(0x03));
            if bitand(ch1_mode, uint8(0x08)) ~= 0
                ch1_src_function = 'CURRENT';
            else
                ch1_src_function = 'VOLTAGE';
            end
            if strcmp(ch1_src_function, 'CURRENT')
                ch1_src_val = (ch1_src_dac_val - obj.src_current_offsets(1, ch1_current_range + 1)) / obj.src_current_gains(1, ch1_current_range + 1);
            else
                ch1_src_val = (ch1_src_dac_val - obj.src_voltage_offsets(1, ch1_current_range + 1)) / obj.src_voltage_gains(1, ch1_current_range + 1);
            end
            if bitand(ch1_mode, uint8(0x04)) ~= 0
                ch1_meas_function = 'VOLTAGE';
            else
                ch1_meas_function = 'CURRENT';
            end
            if strcmp(ch1_meas_function, 'CURRENT')
                ch1_meas_val = obj.meas_current_gains(1, ch1_current_range + 1) * (ch1_meas_adc_val + obj.meas_current_offsets(1, ch1_current_range + 1));
            else
                ch1_meas_val = obj.meas_voltage_gain(1) * (ch1_meas_adc_val + obj.meas_voltage_offset(1));
            end

            ch2_mode = uint8(resp(4));
            ch2_src_dac_val = resp(5);
            ch2_meas_adc_val = resp(6);

            ch2_current_range = bitand(ch2_mode, uint8(0x03));
            if bitand(ch2_mode, uint8(0x08)) ~= 0
                ch2_src_function = 'CURRENT';
            else
                ch2_src_funciton = 'VOLTAGE';
            end
            if strcmp(ch2_src_function, 'CURRENT')
                ch2_src_val = (ch2_src_dac_val - obj.src_current_offsets(2, ch2_current_range + 1)) / obj.src_current_gains(2, ch2_current_range + 1);
            else
                ch2_src_val = (ch2_src_dac_val - obj.src_voltage_offsets(2, ch2_current_range + 1)) / obj.src_voltage_gains(2, ch2_current_range + 1);
            end
            if bitand(ch2_mode, uint8(0x04)) ~= 0
                ch2_meas_function = 'VOLTAGE';
            else
                ch2_meas_function = 'CURRENT';
            end
            if strcmp(ch2_meas_function, 'CURRENT')
                ch2_meas_val = obj.meas_current_gains(2, ch2_current_range + 1) * (ch2_meas_adc_val + obj.meas_current_offsets(2, ch2_current_range + 1));
            else
                ch2_meas_val = obj.meas_voltage_gain(2) * (ch2_meas_adc_val + obj.meas_voltage_offset(2));
            end

            ret = {ch1_current_range, ch1_src_function, ch1_src_val, ch1_meas_function, ch1_meas_val, ...
                   ch2_current_range, ch2_src_function, ch2_src_val, ch2_meas_function, ch2_meas_val};
        end

        function ret = read_serial_number(obj)
            ret = '';
            if ~obj.connected
                return
            end

            vals = obj.flash_read(uint32(0xFC00), 4);
            if vals(3) == 255
                return
            end
            length = uint16(vals(1) + 256 * vals(2));
            words = idivide(length, 3);
            extra_bytes = mod(length, 3);

            address = 0xFC02;
            vals = [];
            for i = 0:words - 1
                resp = obj.flash_read(address, 3);
                vals = [vals, resp(1:3)];
                address = address + 2;
            end
            if extra_bytes ~= 0
                resp = obj.flash_read(address, extra_bytes);
                vals = [vals, resp(1:extra_bytes)];
            end

            ret = char(vals);
        end

        function read_calibration_values(obj)
            if ~obj.connected
                return
            end

            for channel = 0:1
                vals = obj.flash_read(0x10000 + 2 * channel, 4);
                if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                    val = (vals(1) + 256 * vals(2) + 65536 * vals(3)) / 2 ^ 23;
                    obj.meas_voltage_gain(channel + 1) = val * smu.nominal_meas_voltage_gain(channel + 1);
                end
            end

            for channel = 0:1
                vals = obj.flash_read(0x10004 + 2 * channel, 4);
                if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                    val = (vals(1) + 256 * vals(2) + 65536 * vals(3));
                    if val >= 2 ^ 23
                        val = -(val - 2 ^ 23);
                    end
                    obj.meas_voltage_offset(channel + 1) = val / 256.;
                end
            end

            for channel = 0:1
                for current_range = 0:3
                    vals = obj.flash_read(0x10008 + 2 * (4 * channel + current_range), 4);
                    if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                        val = (vals(1) + 256 * vals(2) + 65536 * vals(3)) / 2^23;
                        obj.src_voltage_gains(channel + 1, current_range + 1) = val * smu.nominal_src_voltage_gains(channel + 1, current_range + 1);
                    end
                end
            end

            for channel = 0:1
                for current_range = 0:3
                    vals = obj.flash_read(0x10018 + 2 * (4 * channel + current_range), 4);
                    if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                        val = (vals(1) + 256 * vals(2) + 65536 * vals(3));
                        if val >= 2 ^ 23
                            val = -(val - 2 ^ 23);
                        end
                        obj.src_voltage_offsets(channel + 1, current_range + 1) = val / 256.;
                    end
                end
            end

            for channel = 0:1
                for current_range = 0:3
                    vals = obj.flash_read(0x10028 + 2 * (4 * channel + current_range), 4);
                    if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                        val = (vals(1) + 256 * vals(2) + 65536 * vals(3)) / 2 ^ 23;
                        obj.src_current_gains(channel + 1, current_range + 1) = val * smu.nominal_src_current_gains(channel + 1, current_range + 1);
                    end
                end
            end

            for channel = 0:1
                for current_range = 0:3
                    vals = obj.flash_read(0x10038 + 2 * (4 * channel + current_range), 4);
                    if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                        val = (vals(1) + 256 * vals(2) + 65536 * vals(3));
                        if val >= 2 ^ 23
                            val = -(val - 2 ^ 23);
                        end
                        obj.src_current_offsets(channel + 1, current_range + 1) = val / 256.;
                    end
                end
            end

            for channel = 0:1
                for current_range = 0:3
                    vals = obj.flash_read(0x10048 + 2 * (4 * channel + current_range), 4);
                    if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                        val = (vals(1) + 256 * vals(2) + 65536 * vals(3)) / 2 ^ 23;
                        obj.meas_current_gains(channel + 1, current_range + 1) = val * smu.nominal_meas_current_gains(channel + 1, current_range + 1);
                    end
                end
            end

            for channel = 0:1
                for current_range = 0:3
                    vals = obj.flash_read(0x10058 + 2 * (4 * channel + current_range), 4);
                    if (vals(1) ~= 255) || (vals(2) ~= 255) || (vals(3) ~= 255)
                        val = (vals(1) + 256 * vals(2) + 65536 * vals(3));
                        if val >= 2 ^ 23
                            val = -(val - 2 ^ 23);
                        end
                        obj.meas_current_offsets(channel + 1, current_range + 1) = val / 256.;
                    end
                end
            end
        end
    end
end
