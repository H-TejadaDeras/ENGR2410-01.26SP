R_fit = 1.48377e3;
m = 1/R_fit;   
b = 0; 

Vfit = linspace(min(voltages), max(voltages), 200);
Ifit = m*Vfit + b;

figure
hold on

plot(voltages, currents, '.','MarkerSize',12)
plot(Vfit, Ifit, '-','LineWidth',2)

xlabel('Voltage (V)')
ylabel('Current (A)')
title('I–V Curve with Linear Fit')

text(0.05*max(voltages), 0.9*max(currents), ...
     sprintf('R = %.3f k\\Omega', R_fit/1000), ...
     'FontSize', 12)

legend('Measured Data','Theoretical Fit','Location','best')
hold off
