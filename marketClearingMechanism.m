    %%
    function [arrayActor, tradingArray, edgePerc] = marketClearingMechanism( ...
        arrayActor, numActor, totalStep, ...
        P_grid, C_feedback, C_networkfee, C_platform, switch_Cong, lim_Cong, mode_Cong, edgeList)
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
        numEdges = size(edgeList,1);
         edgePerc = zeros(numEdges,totalStep);
    %%
    numEdges = size(edgeList,1);
edgePerc = zeros(numEdges,totalStep);

G = graph(edgeList(:,1), edgeList(:,2));
pathEdges = cell(numActor,numActor);

for seller = 1:numActor
    for buyer = 1:numActor
        if seller ~= buyer

            nodes = shortestpath(G, seller, buyer);
            edgePath = [];

            for k = 1:length(nodes)-1
                edgeID = find( ...
                    (edgeList(:,1)==nodes(k)   & edgeList(:,2)==nodes(k+1)) | ...
                    (edgeList(:,2)==nodes(k)   & edgeList(:,1)==nodes(k+1)));

                edgePath = [edgePath edgeID];
            end

            pathEdges{seller,buyer} = edgePath;
        end
    end
end
%%
        for j = 1:totalStep
    %%
%     numEdges = size(edgeList,1);
% 
% usedEdgeCapacity = zeros(numEdges,1);
% 
% pathEdges = cell(numActor,numActor);
% 
% G = graph(edgeList(:,1),edgeList(:,2));
% 
% pathEdges = cell(numActor,numActor);
% 
% for seller = 1:numActor
% 
%     for buyer = 1:numActor
% 
%         if seller ~= buyer
% 
%             nodes = shortestpath(G,seller,buyer);
% 
%             edgePath = [];
% 
%             for k = 1:length(nodes)-1
% 
%                 edgeID = find( ...
%                     (edgeList(:,1)==nodes(k)   & edgeList(:,2)==nodes(k+1)) | ...
%                     (edgeList(:,2)==nodes(k)   & edgeList(:,1)==nodes(k+1)));
% 
%                 edgePath = [edgePath edgeID];
% 
%             end
% 
%             pathEdges{seller,buyer} = edgePath;
% 
%         end
% 
%     end
% 
% end
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
    %%
    usedEdgeCapacity = zeros(numEdges,1);
            %% Greedy market clearing
    
    mat_Cong = zeros(numActor,numActor);
    
    for sIdx = 1:length(activeSell)
    
        seller = activeSell(sIdx);
    
        for bIdx = 1:length(activeBuy)
    
            buyer = activeBuy(bIdx);
    
            % Only trade if buyer bid >= seller ask
            if arrayActor(3,buyer,j) >= arrayActor(4,seller,j)
    
               unconstrainedTrade = min(remainingSell(seller), remainingBuy(buyer));

               if strcmp(switch_Cong, 'On')

                    switch mode_Cong

                      case 'Fully Connected'

                        % Direct edge between seller and buyer
                        path = pathEdges{seller,buyer};

                      case 'Path specific (7 actors)'

                        % Physical path through network tree
                        path = pathEdges{seller,buyer};

                    otherwise
                        error('Unknown congestion mode selected');
                   end

                    if isempty(path)
                        tradedEnergy = 0;
                    else
                        remainingPathCapacity = min(edgeList(path,3) - usedEdgeCapacity(path));
                        tradedEnergy = min(unconstrainedTrade, remainingPathCapacity);
                    end

                else
                    tradedEnergy = unconstrainedTrade;
                    path = [];
                end
    
                if tradedEnergy > 1e-9
    
                    tradingArray(tradeRow,1,j) = seller;
                    tradingArray(tradeRow,2,j) = buyer;
                    tradingArray(tradeRow,3,j) = tradedEnergy;
    
                    arrayActor(9,seller,j) = arrayActor(9,seller,j) + tradedEnergy;
                    arrayActor(9,buyer,j)  = arrayActor(9,buyer,j)  + tradedEnergy;
    
                    remainingSell(seller) = remainingSell(seller) - tradedEnergy;
                    remainingBuy(buyer)   = remainingBuy(buyer) - tradedEnergy;
    
                    if strcmp(switch_Cong, 'On') && ~isempty(path)
                        usedEdgeCapacity(path) = usedEdgeCapacity(path) + tradedEnergy;
                    end

                    totalP2P = totalP2P + tradedEnergy;
                    marginalAsk = arrayActor(4,seller,j);
    
                    
    
                    tradeRow = tradeRow + 1;
                end
            end
    
            % Stop checking buyers if this seller has no supply left
            if remainingSell(seller) <= 1e-9
                break;
            end
        end
    end
edgePerc(:,j) = usedEdgeCapacity ./ edgeList(:,3);
edgePerc(:,j) = min(edgePerc(:,j),1);
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
    %%
edgePerc(:,j) = usedEdgeCapacity ./ edgeList(:,3);
edgePerc(:,j) = min(edgePerc(:,j),1);
        end
    end