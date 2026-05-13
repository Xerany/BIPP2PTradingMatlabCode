function results = runP2PModel(inputs)
% runP2PModel
% Wrapper function for the P2P trading model.
% This function:
% 1. Reads input values
% 2. Initializes the actor array
% 3. Calls the market clearing mechanism
% 4. Processes outputs for plotting

    %% Read inputs
    P_grid = inputs.P_grid;
    C_feedback = inputs.C_feedback;
    C_networkfee = inputs.C_networkfee;
    C_platform = inputs.C_platform;

    vecConsumption = inputs.vecConsumption;
    vecGeneration  = inputs.vecGeneration;
    vecBuy         = inputs.vecBuy;
    vecSell        = inputs.vecSell;

    pricingMechanism = inputs.pricingMechanism;

    timestep = inputs.timestep;
    horizon  = inputs.horizon;

    %% Initialize actor matrix
    numActor = length(vecConsumption);
    numChar = 13;

    matActor = zeros(numChar,numActor);

    % Row meaning:
    % 1 Consumption
    % 2 Generation
    % 3 Buy price
    % 4 Sell price
    % 5 Net energy need
    % 6 Money paid
    % 7 Money received
    % 8 Grid import/export
    % 9 Internal P2P trade
    % 10 Clearing price
    % 11 = DSO revenue from network fee
    % 12 = Platform revenue from platform fee
    % 13 = Reference revenue/cost on larger grid

    matActor(1:4,:) = [vecConsumption; vecGeneration; vecBuy; vecSell];

    %% Time settings
    totalStep = horizon / timestep;
    timeVec = (0:totalStep-1) * timestep;

    %% Create 3D actor array
    arrayActor = matActor;

    for k = 2:totalStep
        arrayActor = cat(3,arrayActor,matActor);
    end

    %% Calculate net energy need
    for j = 1:totalStep
        for i = 1:numActor
            arrayActor(5,i,j) = arrayActor(1,i,j) - arrayActor(2,i,j);
        end
    end

    %% Run market clearing mechanism
    if pricingMechanism == 'MarketClearing'
    [arrayActor, tradingArray] = marketClearingMechanism( ...
        arrayActor, numActor, totalStep, ...
        P_grid, C_feedback, C_networkfee, C_platform);
    else
        disp('Error, wrong pricing mechanism input')
        return
    end
    %% Process results for plotting
    vecP2P = zeros(1,totalStep);
    vecClearPrice = zeros(1,totalStep);
    vecGridImport = zeros(1,totalStep);
    vecGridExport = zeros(1,totalStep);

    for j = 1:totalStep
        vecP2P(j) = sum(arrayActor(9,:,j)) / 2;
        vecClearPrice(j) = arrayActor(10,1,j);

        totalImport = 0;
        totalExport = 0;

        for i = 1:numActor
            surplus = max(arrayActor(2,i,j) - arrayActor(1,i,j), 0);
            deficit = max(arrayActor(1,i,j) - arrayActor(2,i,j), 0);

            if surplus > 0
                totalExport = totalExport + arrayActor(8,i,j);
            elseif deficit > 0
                totalImport = totalImport + arrayActor(8,i,j);
            end
        end

        vecGridImport(j) = totalImport;
        vecGridExport(j) = totalExport;
    end

    %% Store outputs
    results.arrayActor = arrayActor;
    results.tradingArray = tradingArray;
    results.timeVec = timeVec;
    results.vecP2P = vecP2P;
    results.vecClearPrice = vecClearPrice;
    results.vecGridImport = vecGridImport;
    results.vecGridExport = vecGridExport;
end

%%
