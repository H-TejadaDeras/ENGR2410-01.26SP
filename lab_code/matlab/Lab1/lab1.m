data = readtable('recovered_points.csv');

voltages = data.Voltage_V;
currents = data.Current_A;


p = polyfit(voltages, currents, 1);
m = p(1);
b = p(2);

% resistance from slope
R_fit = 1/m;

Vfit = linspace(min(voltages), max(voltages), 200);
Ifit = m * Vfit + b;


figure
hold on

plot(voltages, currents, '.', 'MarkerSize', 13)
plot(Vfit, Ifit, '-', 'LineWidth', 2)

xlabel('Voltage (V)')
ylabel('Current (A)')
title('I–V Curve with Linear Fit')

text(0.05*max(voltages), 0.9*max(currents), ...
     sprintf('R = %.3f k\\Omega', R_fit/1000), ...
     'FontSize', 12)

legend('Measured Data', 'Best Fit', 'Location', 'best')
xlim([-1 1.05])
hold off


fprintf('Slope (A/V): %.6e\n', m);
fprintf('Intercept (A): %.6e\n', b);
fprintf('Resistance (Ohms): %.6f\n', R_fit);
fprintf('Resistance (kOhms): %.6f\n', R_fit/1000);