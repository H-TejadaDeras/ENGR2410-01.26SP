
s.set_source_function(1, 'VOLTAGE');
s.set_measure_function(1, 'CURRENT');
s.set_source_function(2, 'CURRENT');
s.set_measure_function(2, 'VOLTAGE');
s.source_current(2, 0);

vin = linspace(-1, 1, 101);
vout = zeros(1, length(vin));

s.source_voltage(1, vin(1));
s.autorange_once(1);
pause(0.1);

for i = 1:length(vin)
    s.source_voltage(1, vin(i));
    s.autorange_once(1);

    vout(i) = s.measure_voltage(2);
    if i > 0
        plot(vin(1:i), vout(1:i), '.-');
        xlabel('Vin (V)');
        ylabel('Vout (V)');
        drawnow();
    end
end

plot(vin, vout, '.-');
xlabel('Vin (V)');
ylabel('Vout (V)');

