
% CH1 sources the resistor voltage and measures its current

s.set_source_function(1, 'VOLTAGE');
s.set_measure_function(1, 'CURRENT');

voltages = linspace(-1, 1, 101);
currents = zeros(1, length(voltages));

s.source_voltage(1, voltages(1));
s.autorange_once(1);
pause(0.1);

for i = 1:length(voltages)
    s.source_voltage(1, voltages(i));
    s.autorange_once(1);
    currents(i) = s.measure_current(1);
    if i > 1
        plot(voltages(1:i), currents(1:i), '.-');
        xlabel('Voltage (V)');
        ylabel('Current (A)');
        drawnow();
    end
end

plot(voltages, currents, '.-');
xlabel('Voltage (V)');
ylabel('Current (A)');

