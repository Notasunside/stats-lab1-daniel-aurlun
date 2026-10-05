%%--lab1 %
clear;
clc;
% clf;
close all;

%--folder containing our script and the data files %
outputFolder = fileparts ( mfilename ( 'fullpath') ); 
if isempty ( outputFolder)
    outputFolder = pwd;
end

%% --load data%
sensor1= readtable( fullfile( outputFolder, 'lidar_1_data.csv') ); 
sensor2 = readtable( fullfile( outputFolder, 'lidar_2_data.csv') ); 

stopDists = [5, 10, 15];
names = {'sensor 1', 'sensor 2'};
tables = {sensor1, sensor2}; %--we put both tables into an arra%
alpha = 0.05;
sensorColors = { [0.25 0.55 0.80], [0.95 0.55 0.25] };

%% --calc stats and tests for every sensor dist wombo %

row = 1;
for index = 1:2
    currentTable = tables{index};
    for dInd = 1:length( stopDists)
        dTrue = stopDists( dInd ); 
        measurements = currentTable.Measured( currentTable.Truth == dTrue ); 
            sensor{row , 1} = names{index};
            truth_ft( row , 1) = dTrue; %--ft = in feet %
            mean_ft( row , 1) = mean( measurements ); 
            stddev_ft( row, 1) = std( measurements );  %--sample standard deviation  ( n-1)   %-- mu = true distance %
        [rejectH0( row, 1), pValue( row, 1), ~, testStats]= ttest( measurements, dTrue, 'Alpha', alpha ); 
        tStatistic( row, 1) = testStats.tstat;
        %--normality assumption tes %
        [rejectNormal( row, 1), normalPValue( row, 1) ] = lillietest( measurements, 'Alpha', alpha ); 
            row = row + 1;
    end
end

resultsTable = table ( sensor, truth_ft, mean_ft, stddev_ft , tStatistic, pValue, rejectH0, normalPValue, rejectNormal ); 
disp( 'Descriptive statistics, t-tests, and normality tests:' ); 
disp( resultsTable ); 

%% --fitted normal distributions %

for index = 1:2
    currentTable = tables{index};

    figure( 'Color', 'white', 'Name', [names{index} ' distributions'] ); 
    tiledlayout( 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact' ); 

    for dInd = 1:length( stopDists)
            dTrue = stopDists( dInd ); 
            measurements = currentTable.Measured( currentTable.Truth == dTrue ); 
            mu = mean( measurements ); 
            sigma = std( measurements ); 
        nexttile;
        histogram( measurements, 'Normalization', 'pdf', 'FaceColor', sensorColors{index}, 'FaceAlpha', 0.65, 'EdgeColor', 'white' ); 
        hold on;
            x = linspace( min( measurements) - 0.2, max( measurements) + 0.2, 300 ); 
            pdf = normpdf( x, mu, sigma );  %--probability density function = pdf %
        plot( x, pdf, 'k-', 'LineWidth', 2 ); 
        xline( dTrue, '--r', 'truth', 'LineWidth', 1.5 ); 
        xline( mu, ':b', 'mean', 'LineWidth', 1.5 ); 
        grid on;
        xlabel( 'measured distance  ( ft)' ); 
        ylabel( 'probability density' ); 
        title( sprintf( '%g-ft test', dTrue) ); 
        legend( 'measurements', 'fitted normal', 'truth', 'mean', 'Location', 'best' ); 
    end
    sgtitle( [names{index} ': measurements with fitted normal distributions'] ); 
    %--i saved each fig in our repo so that LaTeX can reference it %
    if index == 1
        exportgraphics(gcf, fullfile( outputFolder, 'sensor_1_distributions.png'), 'Resolution', 300 ); 
    else
        exportgraphics( gcf, fullfile( outputFolder, 'sensor_2_distributions.png'), 'Resolution', 300 ); 
    end
end

%% --compare both sensors %

figure( 'Color', 'white', 'Name', 'sensor comparison' ); 
tiledlayout( 1, 2,'TileSpacing', 'compact','Padding', 'compact' ); 
nexttile;
hold on;
for index = 1:2
        rows = strcmp ( resultsTable.sensor, names{index} ); 
    errorbar ( resultsTable.truth_ft( rows), resultsTable.mean_ft( rows), resultsTable.stddev_ft( rows), '-o', 'LineWidth', 1.5 ); 
end
plot( stopDists, stopDists, '--k', 'LineWidth', 1.5 ); 
grid on;
xlabel( 'true distance  ( ft)' ); 
ylabel( 'mean measured distance  ( ft)' ); 
title( 'accuracy with +/-1 sample standard deviation' ); 
legend( 'sensor 1', 'sensor 2', 'perfect accuracy', 'Location', 'northwest' ); 
nexttile;
hold on;

for index = 1:2
        rows = strcmp( resultsTable.sensor, names{index} ); 
    plot( resultsTable.truth_ft( rows ) , resultsTable.stddev_ft( rows) , '-o' , 'LineWidth' , 1.5, 'MarkerSize' , 7 ); 
end

grid on;
xlabel( 'true distance  ( ft)' ); 
ylabel( 'sample standard deviation  ( ft)' ); 
title( 'precision comparison' ); 
legend( 'sensor 1', 'sensor 2', 'Location', 'best' ); 
sgtitle( 'LiDAR sensor accuracy and precision' ); 
exportgraphics( gcf, fullfile( outputFolder, 'sensor_comparison.png'), 'Resolution', 300 ); 

%% -- mc sim %

rng( 82 );  %--fixes seed :) %
    numTrials = 1000000;
for dInd = 1:length( stopDists)
        dTrue = stopDists( dInd ); 
        sensor1Measurements = sensor1.Measured( sensor1.Truth == dTrue ); 
        sensor2Measurements = sensor2.Measured( sensor2.Truth == dTrue ); 
        sensor1Sim = normrnd( mean( sensor1Measurements), std( sensor1Measurements), numTrials , 1 ); 
        sensor2Sim = normrnd( mean( sensor2Measurements), std( sensor2Measurements), numTrials , 1 ); 
        tooCloseLimit_ft( dInd, 1) = dTrue - 0.5;
        bothTooClose = sensor1Sim <= tooCloseLimit_ft( dInd) & sensor2Sim <= tooCloseLimit_ft( dInd ); 
    bothTooClosePercent( dInd , 1) = 100 * sum( bothTooClose) / numTrials;
end

    monteCarloTable = table( stopDists' , tooCloseLimit_ft , ...
    bothTooClosePercent, 'VariableNames',{'truth_ft', 'tooCloseLimit_ft', 'bothTooClosePercent'} ); 

disp( 'Monte Carlo results:' ); 
disp( monteCarloTable ); 

%% -- mc figure %

figure( 'Color', 'white', 'Name', 'Monte Carlo results' ); 
semilogy( stopDists , bothTooClosePercent, '-o', 'Color' , [0.90 0.35 0.10], 'MarkerFaceColor' , [0.90 0.35 0.10], ...
    'LineWidth', 2 , 'MarkerSize', 8 ); 
grid on;
xticks( stopDists ); 
xlabel( 'true distance  (ft)' ); ylabel( 'both sensors too close  ( %)' ); 
title( 'Monte Carlo probability that both sensors read too close' ); 
    exportgraphics( gcf, fullfile ( outputFolder,'monte_carlo_results.png'), 'Resolution', 300 ); 
