%%
function [arrayActor, tradingArray] = marketClearingMechanism( ...
    arrayActor, numActor, totalStep, ...
    P_grid, C_feedback, C_networkfee, C_platform)
% marketClearingMechanism
% Performs the P2P market clearing and financial settlement.
%
% Mechanism:
% 1. Sellers are ordered from lowest to highest asking price.
% 2. Buyers are ordered from highest to lowest willingness to pay.
% 3. The cheapest seller is matched with the highest-paying buyer.
% 4. A trade occurs if buyer bid >= seller ask.
% 5. The traded amount equals the minimum of remaining supply and demand.
% 6. The clearing price is set as the marginal seller ask.
% 7. Remaining buyer demand is imported from the grid.
% 8. Remaining seller surplus is exported to the grid.

    tradingArray = zeros(30,4,totalStep);

    for j = 1:totalStep

        %% Sort market participants
        [~,orderSell] = sort(arrayActor(4,:,j));              % low ask first
        [~,orderBuy]  = sort(arrayActor(3,:,j),'descend');    % high bid first

        %% Determine available supply and demand
        remainingSell = max(arrayActor(2,:,j) - arrayActor(1,:,j), 0);
        remainingBuy  = max(arrayActor(1,:,j) - arrayActor(2,:,j), 0);

        activeSell = orderSell(remainingSell(orderSell) > 0);
        activeBuy  = orderBuy(remainingBuy(orderBuy) > 0);

        %% Initialize clearing variables
        s = 1;
        b = 1;
        tradeRow = 1;
        totalP2P = 0;
        marginalAsk = 0;

        %% Greedy market clearing
        while s <= length(activeSell) && b <= length(activeBuy)

            seller = activeSell(s);
            buyer  = activeBuy(b);

            % Trade only if buyer is willing to pay at least the seller ask
            if arrayActor(3,buyer,j) >= arrayActor(4,seller,j)

                tradedEnergy = min(remainingSell(seller), remainingBuy(buyer));

                if tradedEnergy > 0

                    % Store trade: [seller ID, buyer ID, energy, clearing price later]
                    tradingArray(tradeRow,1,j) = seller;
                    tradingArray(tradeRow,2,j) = buyer;
                    tradingArray(tradeRow,3,j) = tradedEnergy;

                    % Store internal trade for both seller and buyer
                    arrayActor(9,seller,j) = arrayActor(9,seller,j) + tradedEnergy;
                    arrayActor(9,buyer,j)  = arrayActor(9,buyer,j)  + tradedEnergy;

                    % Update remaining supply and demand
                    remainingSell(seller) = remainingSell(seller) - tradedEnergy;
                    remainingBuy(buyer)   = remainingBuy(buyer) - tradedEnergy;

                    totalP2P = totalP2P + tradedEnergy;
                    marginalAsk = arrayActor(4,seller,j);

                    tradeRow = tradeRow + 1;
                end

                % Move to next seller if current seller is empty
                if remainingSell(seller) <= 1e-9
                    s = s + 1;
                end

                % Move to next buyer if current buyer is satisfied
                if remainingBuy(buyer) <= 1e-9
                    b = b + 1;
                end

            else
                % If current buyer cannot afford current seller,
                % no further trade is possible due to sorting.
                break;
            end
        end

        %% Determine uniform clearing price
        if totalP2P > 0
            p_clear = marginalAsk;
        else
            p_clear = 0;
        end

        arrayActor(10,:,j) = p_clear;

        %% Store clearing price in trading array
        for r = 1:size(tradingArray,1)
            if tradingArray(r,3,j) > 0
                tradingArray(r,4,j) = p_clear;
            end
        end

       %% Settlement
buyerP2PPrice = p_clear + C_networkfee + C_platform;

for i = 1:numActor

    surplus = max(arrayActor(2,i,j) - arrayActor(1,i,j), 0);
    deficit = max(arrayActor(1,i,j) - arrayActor(2,i,j), 0);
    internalTrade = arrayActor(9,i,j);

    if surplus > 0

        % Seller revenue from P2P
        p2pSold = internalTrade;
        arrayActor(7,i,j) = p2pSold * p_clear;

        % Remaining surplus exported to external grid
        gridExport = surplus - p2pSold;

        if gridExport < 0
            disp('error gridExport: clear+clc before running again')
        end

        arrayActor(8,i,j) = gridExport;

        % Seller revenue from external grid export
        arrayActor(7,i,j) = arrayActor(7,i,j) + gridExport * (P_grid - C_feedback);

        % Reference: revenue if all surplus was sold to larger grid
        arrayActor(13,i,j) = surplus * (P_grid - C_feedback);

    elseif deficit > 0

        % Buyer payment for P2P
        p2pBought = internalTrade;
        arrayActor(6,i,j) = p2pBought * buyerP2PPrice;

        % DSO and platform revenue from internal P2P trade
        arrayActor(11,i,j) = p2pBought * C_networkfee;
        arrayActor(12,i,j) = p2pBought * C_platform;

        % Remaining demand imported from external grid
        gridImport = deficit - p2pBought;

        if gridImport < 0
            disp('error gridImport: clear+clc before running again')
        end

        arrayActor(8,i,j) = gridImport;

        % Buyer payment for external grid import
        arrayActor(6,i,j) = arrayActor(6,i,j) + gridImport * (P_grid + C_networkfee);

        % DSO revenue from grid import network fee
        arrayActor(11,i,j) = arrayActor(11,i,j) + gridImport * C_networkfee;

        % Reference: cost if all demand was bought from larger grid
        arrayActor(13,i,j) = deficit * (P_grid + C_networkfee);

    end
end

    end
end