
% CH1 sources base voltage and measures base current
% CH2 sources collector voltage and measures collector current

s.set_source_function(1, 'VOLTAGE');
s.set_measure_function(1, 'CURRENT');
s.set_source_function(2, 'VOLTAGE');
s.set_measure_function(2, 'CURRENT');

vb = fliplr(0.25:0.005:0.7);
ib = zeros(1, length(vb));
ic = zeros(1, length(vb));

s.source_voltage(1, vb(1));
s.autorange_once(1);
s.source_voltage(2, vb(1));
s.autorange_once(2);
pause(0.1);

for i = 1:length(vb)
    s.source_voltage(1, vb(i));
    s.autorange_once(1);
    s.source_voltage(2, vb(i));
    s.autorange_once(2);

    ib(i) = s.measure_current(1);
    ic(i) = s.measure_current(2);
    if i > 0
        semilogy(vb(1:i), [ib(1:i); ic(1:i)], '.-');
        xlabel('Vb (V)');
        ylabel('Ib, Ic (A)');
        drawnow();
    end
end

semilogy(vb, [ib; ic], '.-');
xlabel('Vb (V)');
ylabel('Ib, Ic (A)');
