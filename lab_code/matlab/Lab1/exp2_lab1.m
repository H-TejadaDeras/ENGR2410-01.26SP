clf
figure();
hold on
scatter(Vsource, Vout, '.', DisplayName='Measured Data')
xlabel('V_{source} (V)')
ylabel('V_{out} (V)')

p = polyfit(Vsource, Vout, 1);
f = polyval(p, Vsource);

plot(Vsource, f, DisplayName='Line of Best Fit')

legend(Location="best");
title('Voltage Divider Transfer Characteristic')