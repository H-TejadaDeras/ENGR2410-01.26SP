clf
figure();
hold on
scatter(Vsource, Vout, '.', DisplayName='Measured Data')
xlabel('V_{source} (V)')
ylabel('V_{out} (V)')

p = polyfit(Vsource, Vout, 1);
f = polyval(p, Vsource);

plot(Vsource, f, DisplayName='Line of Best Fit')

text(0.05*max(Vsource), 0.9*max(Vout), ...
     sprintf('Measured Voltage Divider Ratio: %.4f', p(1, 1)), ...
     'FontSize', 12)

legend(Location="best");
title('Voltage Divider Transfer Characteristic')