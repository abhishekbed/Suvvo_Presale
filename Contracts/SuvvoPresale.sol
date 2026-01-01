// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface Aggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract SuuvoPreSale is Ownable {
    struct TokenDistrubuteInfo {
        string name;
        uint16 tokenDistrubutedPercentage;
        uint256 totalPhaseToken;
        uint16 releasePercentage;
        uint256 totalSuppliedToken;
    }

    struct TokenVestingInfo {
        address beneficiary;
        uint256 SuuvoToken;
        uint256 remainingToken;
        uint256 startTime;
        uint256 vestingDuration;
        uint256 lastClaimTime;
        uint256 releaseInterval;
        uint256 initialCliff;
        string phaseName;
    }

    struct PrivateSaleRound {
        string roundName;
        uint16 RoundAllocationPercentage;
        uint256 tokenAllocated;
        uint256 fundRaised;
        uint256 releaseTime;
        uint256 cliffTime;
        uint256 vestingDuration;
        uint256 startTime;
        uint256 endTime;
        uint256 priceInUSD;
        uint256 tokensSold;
        uint256 claimPercentage;
        bool isActive;
    }

    struct Purchase {
        string roundName;
        uint16 roundIndex;
        address user;
        uint256 value;
        uint256 tokenValue;
        uint256 remainingToken;
        uint256 startTime;
        uint256 vestingDuration;
        uint256 lastClaimTime;
        uint256 releaseInterval;
        uint256 initialCliff;
        string coinType;
        bool active;
    }

    struct RefferDetails {
        address refferalAddress;
        uint256 amount;
        bool isClaim;
    }

    struct ReserveInfo {
        address reserveAddress;
        uint256 tokenValue;
    }

    uint256 publicSalePrice = 0.08 ether;
    IERC20 private tokenContract;
    IERC20 private usdtContract;
    address private dataOracle = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    uint16 public activeRoundIndex = 0;
    uint256 public REFERRAL_PERCENTAGE = 30;
    uint256 public referralClaimTime;
    bool public isReferralClaim = false;
    uint256 constant DECIMAL_VALUE = 1e26;
    address payable public receiverAddress;

    PrivateSaleRound[] private rounds;
    mapping(address => Purchase[]) private userPurchases;
    mapping(address => address) private _checkReferrers;
    mapping(address => RefferDetails[]) private _refferInfo;
    mapping(uint256 => TokenDistrubuteInfo) private _tokenDistributeData;
    mapping(address => TokenVestingInfo[]) private advisorTokenData;
    mapping(address => TokenVestingInfo[]) private MarketingTokenData;
    mapping(address => TokenVestingInfo[]) private CSRTokenData;
    ReserveInfo[] public reserveDataInfo;
    address[] public buyers;
    address[] public _teamAndAdvisorList;
    address[] public _marketingList;
    address[] public _CSRList;

    modifier onlyActiveRound() {
        require(
            activeRoundIndex < rounds.length &&
                rounds[activeRoundIndex].isActive,
            "No active round or invalid index"
        );
        _;
    }

    constructor(IERC20 _usdtAddress) Ownable(msg.sender) {
        usdtContract = _usdtAddress;
        uint256 decimal = DECIMAL_VALUE;
        receiverAddress = payable(msg.sender);
        TokenDistrubuteInfo[8] memory arr = [
            TokenDistrubuteInfo("Private Sale", 185, 37 * decimal, 417, 0),
            TokenDistrubuteInfo("Public Sale", 210, 42 * decimal, 0, 0),
            TokenDistrubuteInfo("Ecosystem Fund", 200, 40 * decimal, 278, 0),
            TokenDistrubuteInfo("Team & Advisors", 90, 18 * decimal, 209, 0),
            TokenDistrubuteInfo("Liquidity Pool", 135, 27 * decimal, 0, 0),
            TokenDistrubuteInfo("Reserve Fund", 120, 24 * decimal, 0, 0),
            TokenDistrubuteInfo(
                "Marketing & Development",
                40,
                8 * decimal,
                834,
                0
            ),
            TokenDistrubuteInfo("CSR (NGO)", 20, 4 * decimal, 834, 0)
        ];
        for (uint256 i = 0; i < arr.length; ++i) {
            _tokenDistributeData[i] = arr[i];
        }
        PrivateSaleRound[5] memory roundData = [
            PrivateSaleRound(
                "Pre - Seed",
                45,
                900_000_000 * 10 ** 18,
                900_000,
                6 * 30 days,
                6 * 30 days,
                60 * 30 days,
                0,
                0,
                0.001 ether,
                0,
                10,
                false
            ),
            PrivateSaleRound(
                "Seed",
                45,
                900_000_000 * 10 ** 18,
                4_500_000,
                3 * 30 days,
                6 * 30 days,
                36 * 30 days,
                0,
                0,
                0.005 ether,
                0,
                12,
                false
            ),
            PrivateSaleRound(
                "Presale R1",
                40,
                800_000_000 * 10 ** 18,
                8_000_000,
                30 days,
                3 * 30 days,
                18 * 30 days,
                0,
                0,
                0.01 ether,
                0,
                18,
                false
            ),
            PrivateSaleRound(
                "Presale R2",
                30,
                600_000_000 * 10 ** 18,
                24_000_000,
                30 days,
                3 * 30 days,
                18 * 30 days,
                0,
                0,
                0.04 ether,
                0,
                18,
                false
            ),
            PrivateSaleRound(
                "Presale R3",
                25,
                500_000_000 * 10 ** 18,
                30_000_000,
                30 days,
                30 days,
                12 * 30 days,
                0,
                0,
                0.06 ether,
                0,
                12,
                false
            )
        ];
        for (uint256 i = 0; i < roundData.length; ++i) {
            rounds.push(roundData[i]);
        }
    }

    function changeDataoracleAddress(address newAddress) public onlyOwner {
        require(newAddress != address(0), "INVALID_DATA_ORACLE_ADDRESS");
        require(dataOracle != newAddress, "SAME_ADDRESS");
        dataOracle = newAddress;
    }

    function changeUSDTAddress(IERC20 _usdtAddress) external onlyOwner {
        usdtContract = _usdtAddress;
    }

    function setContractAddress(IERC20 _tokenAddress) external onlyOwner {
        tokenContract = _tokenAddress;
    }

    function claimPublicSaleandLiquidity(
        address publicAddress,
        address liquidityAddress
    ) external onlyOwner {
        require(
            publicAddress != address(0) && liquidityAddress != address(0),
            "given valid address"
        );
        TokenDistrubuteInfo storage publicData = _tokenDistributeData[1];
        TokenDistrubuteInfo storage liquidityData = _tokenDistributeData[4];
        require(
            publicData.totalSuppliedToken != publicData.totalPhaseToken,
            "already token transfer"
        );
        tokenContract.transfer(publicAddress, publicData.totalPhaseToken);
        tokenContract.transfer(liquidityAddress, liquidityData.totalPhaseToken);
        publicData.totalSuppliedToken = publicData.totalPhaseToken;
        liquidityData.totalSuppliedToken = liquidityData.totalPhaseToken;
    }

    function claimReserveToken(
        address reserveAddress,
        uint256 amount
    ) external onlyOwner {
        require(
            reserveAddress != address(0) && amount != 0,
            "please given valis address or price"
        );
        TokenDistrubuteInfo storage reserveData = _tokenDistributeData[5];
        require(
            reserveData.totalPhaseToken >=
                reserveData.totalSuppliedToken + amount,
            "already token transfer"
        );
        reserveData.totalSuppliedToken += amount;
        tokenContract.transfer(reserveAddress, amount);
        reserveDataInfo.push(ReserveInfo(reserveAddress, amount));
    }

    function startRound(
        uint16 _roundIndex,
        uint256 endTime
    ) external onlyOwner {
        require(_roundIndex < rounds.length, "Invalid round index");
        require(endTime > block.timestamp, "please give valid end time");
        if (rounds[activeRoundIndex].isActive) {
            rounds[activeRoundIndex].isActive = false;
            rounds[activeRoundIndex].endTime = block.timestamp;
        }
        activeRoundIndex = _roundIndex;
        PrivateSaleRound storage round = rounds[_roundIndex];
        round.isActive = true;
        round.startTime = block.timestamp;
        round.endTime = endTime;
    }

    function endRound() external onlyOwner onlyActiveRound {
        rounds[activeRoundIndex].isActive = false;
        rounds[activeRoundIndex].endTime = block.timestamp;
    }

    function getETHLatestPrice() public view returns (uint256) {
        (
            uint80 roundID,
            int256 price,
            ,
            uint256 timestamp,
            uint80 answeredInRound
        ) = Aggregator(dataOracle).latestRoundData();
        require(price > 0, "Chainlink price is invalid");
        require(
            answeredInRound >= roundID,
            "Stale price: answered in previous round"
        );
        require(timestamp != 0, "Incomplete round: no timestamp");
        int256 _price = (price / (10 ** 8));
        return uint256(_price);
    }

    function changeReceiverAddress(
        address payable newAddress
    ) external onlyOwner {
        receiverAddress = newAddress;
    }

    function buyTokens(
        uint256 buyOption,
        uint256 amount,
        string memory coinType,
        address referral
    ) external payable onlyActiveRound {
        PrivateSaleRound storage round = rounds[activeRoundIndex];
        require(
            block.timestamp > round.startTime &&
                block.timestamp < round.endTime,
            "round time is complated"
        );
        require(round.isActive == true, "round is inactive");
        address from = msg.sender;
        uint256 tokenPrice = round.priceInUSD;
        uint256 tokensToBuy;
        uint256 usdtValue;
        uint256 value = buyOption == 0 ? amount : msg.value;
        require(amount > 0, "Amount must be greater than zero");
        if (buyOption == 0) {
            require(
                usdtContract.balanceOf(from) >= amount,
                "INSUFFICIENT_USDT_TOKENS"
            );
            tokensToBuy = ((amount * 10 ** 12) * 1e18) / tokenPrice;
            usdtContract.transferFrom(from, receiverAddress, amount);
        } else {
            require(msg.value > 0, "Amount must be greater than zero");
            uint256 ethPriceInUSDT = getETHLatestPrice();
            usdtValue = (ethPriceInUSDT * msg.value);
            tokensToBuy = (usdtValue * 1e18) / tokenPrice;
            (bool success, ) = receiverAddress.call{value: msg.value}("");
            require(success, "ETH transfer failed");
        }
        require(tokensToBuy > 0, "Insufficient value for token purchase");
        uint256 remainingToken = round.tokenAllocated - round.tokensSold;
        require(
            remainingToken >= tokensToBuy,
            "round have not sufficient token"
        );
        round.tokensSold += tokensToBuy;
        if (userPurchases[from].length == 0) {
            buyers.push(from);
        }
        Purchase memory newPurchase = Purchase({
            roundName: round.roundName,
            roundIndex: activeRoundIndex,
            user: from,
            value: value,
            tokenValue: tokensToBuy,
            remainingToken: tokensToBuy,
            startTime: block.timestamp,
            vestingDuration: block.timestamp +
                round.vestingDuration +
                round.cliffTime,
            lastClaimTime: block.timestamp + round.cliffTime,
            releaseInterval: round.releaseTime,
            initialCliff: round.cliffTime,
            coinType: coinType,
            active: true
        });
        userPurchases[from].push(newPurchase);
        TokenDistrubuteInfo storage tokonomicsData = _tokenDistributeData[0];
        tokonomicsData.totalSuppliedToken += tokensToBuy;
        if (_checkReferrers[from] == address(0) && referral != address(0)) {
            addReferAddress(from, referral, tokensToBuy);
        }
    }

    function buyTokensFiatorOtherCoins(
        uint256 USDTAmount,
        address userAddress,
        string memory coinType,
        address referral,
        uint256 value
    ) external payable onlyActiveRound onlyOwner {
        require(
            userAddress != address(0) && USDTAmount > 0,
            "invalid User address or amount"
        );
        PrivateSaleRound storage round = rounds[activeRoundIndex];
        uint256 tokenPrice = round.priceInUSD;
        require(
            block.timestamp > round.startTime &&
                block.timestamp < round.endTime &&
                round.isActive == true,
            "round is inactive"
        );
        uint256 tokensToBuy = (USDTAmount * 1e18) / tokenPrice;
        uint256 remainingToken = round.tokenAllocated - round.tokensSold;
        require(
            remainingToken >= tokensToBuy,
            "round have not sufficient token"
        );
        round.tokensSold += tokensToBuy;
        if (userPurchases[userAddress].length == 0) {
            buyers.push(userAddress);
        }
        Purchase memory newPurchase = Purchase({
            roundName: round.roundName,
            roundIndex: activeRoundIndex,
            user: userAddress,
            value: value,
            tokenValue: tokensToBuy,
            remainingToken: tokensToBuy,
            startTime: block.timestamp,
            vestingDuration: block.timestamp +
                round.vestingDuration +
                round.cliffTime,
            lastClaimTime: block.timestamp + round.cliffTime,
            releaseInterval: round.releaseTime,
            initialCliff: round.cliffTime,
            coinType: coinType,
            active: true
        });
        userPurchases[userAddress].push(newPurchase);
        TokenDistrubuteInfo storage tokonomicsData = _tokenDistributeData[0];
        tokonomicsData.totalSuppliedToken += tokensToBuy;
        if (
            _checkReferrers[userAddress] == address(0) && referral != address(0)
        ) {
            addReferAddress(userAddress, referral, tokensToBuy);
        }
    }

    function getBuyerData(
        address userAddress
    ) public view returns (Purchase[] memory) {
        return userPurchases[userAddress];
    }

    function getAllBuyerData() external view returns (Purchase[] memory) {
        uint256 totalPurchases;
        for (uint256 i = 0; i < buyers.length; i++) {
            totalPurchases += userPurchases[buyers[i]].length;
        }
        Purchase[] memory purchases = new Purchase[](totalPurchases);
        uint256 index;
        for (uint256 i = 0; i < buyers.length; i++) {
            Purchase[] storage buyerPurchases = userPurchases[buyers[i]];
            for (uint256 j = 0; j < buyerPurchases.length; j++) {
                purchases[index] = buyerPurchases[j];
                index++;
            }
        }
        return purchases;
    }

    function claimToken(uint256 index) public {
        Purchase storage user = userPurchases[msg.sender][index];
        require(user.remainingToken != 0, "ALL_TOKENS_CLAIMED");
        uint256 currentTime = block.timestamp;
        require(
            currentTime > user.lastClaimTime + user.releaseInterval,
            "CLAIM_TIME_INCOMPLETE"
        );
        require(user.active, "TOKEN_CLAIMED");
        uint256 tokenClaimed;
        if (currentTime >= user.vestingDuration) {
            tokenClaimed = user.remainingToken;
            user.active = false;
            user.lastClaimTime = user.vestingDuration;
            user.remainingToken = 0;
        } else {
            uint256 totalClaim = (currentTime - user.lastClaimTime) /
                user.releaseInterval;
            tokenClaimed =
                (user.tokenValue / rounds[user.roundIndex].claimPercentage) *
                totalClaim;
            user.lastClaimTime += totalClaim * user.releaseInterval;
            user.remainingToken -= tokenClaimed;
        }
        tokenContract.transfer(msg.sender, tokenClaimed);
    }

    function getNextRoundPrice() public view returns (uint256) {
        uint256 price = activeRoundIndex != rounds.length - 1
            ? rounds[activeRoundIndex + 1].priceInUSD
            : publicSalePrice;
        return price;
    }

    function getAllRoundsData()
        external
        view
        returns (PrivateSaleRound[] memory)
    {
        return rounds;
    }

    function getCurrentRound() external view returns (PrivateSaleRound memory) {
        return rounds[activeRoundIndex];
    }

    function addReferAddress(
        address from,
        address referrer,
        uint256 tokensToBuy
    ) internal {
        require(from != referrer, "REFERRER_CANNOT_BE_A_REFERRAL");
        require(_refferInfo[referrer].length != 20, "referral limit exceed");
        _checkReferrers[from] = referrer;
        uint256 totalReferralToken = (tokensToBuy * REFERRAL_PERCENTAGE) /
            10000;
        _refferInfo[referrer].push(
            RefferDetails(from, totalReferralToken, false)
        );
        TokenDistrubuteInfo storage tokonomicsData = _tokenDistributeData[2];
        tokonomicsData.totalSuppliedToken += totalReferralToken;
    }

    function claimReferralTokens() public {
        require(
            referralClaimTime <= block.timestamp && isReferralClaim,
            "Token Claim time is not completed"
        );
        RefferDetails[] storage referrals = _refferInfo[msg.sender];
        uint256 totalToken = 0;
        uint256 referrerLength = referrals.length;
        for (uint256 i = 0; i < referrerLength; ++i) {
            RefferDetails storage referral = referrals[i];
            if (!referral.isClaim) {
                totalToken += referral.amount;
                referral.isClaim = true;
            }
        }
        require(totalToken != 0, "NO_REFERRAL_TOKENS_AVAILABLE");
        tokenContract.transfer(msg.sender, totalToken);
    }

    function getReferrer(address userAddress) public view returns (address) {
        return _checkReferrers[userAddress];
    }

    function getAllReferralDetails(
        address referrerAddress
    ) public view returns (RefferDetails[] memory) {
        return _refferInfo[referrerAddress];
    }

    function setReferralTime(uint256 referralTime) external onlyOwner {
        require(referralTime > block.timestamp, "given valid time");
        referralClaimTime = referralTime;
        isReferralClaim = true;
    }

    function setReferralAmount(uint256 _referralValue) external onlyOwner {
        require(_referralValue > 0, "INVALID_REFERRAL_AMOUNT");
        REFERRAL_PERCENTAGE = _referralValue;
    }

    function TeamAndAdvisorToken(
        uint256 amount,
        address advisorAddress
    ) external onlyOwner {
        require(
            amount > 0 && advisorAddress != address(0),
            "INVALID_AMOUNT_OR_ADDRESS"
        );
        TokenVestingInfo[] storage advisorTokens = advisorTokenData[
            advisorAddress
        ];
        if (advisorTokens.length == 0) {
            _teamAndAdvisorList.push(advisorAddress);
        }
        TokenDistrubuteInfo storage distributeInfo = _tokenDistributeData[3];
        require(
            distributeInfo.totalSuppliedToken + amount <
                distributeInfo.totalPhaseToken,
            "INSUFFICIENT_TOKENS_IN_PHASE"
        );
        uint256 currentTime = block.timestamp;
        distributeInfo.totalSuppliedToken += amount;
        TokenVestingInfo memory advisorToken = TokenVestingInfo({
            beneficiary: advisorAddress,
            SuuvoToken: amount,
            remainingToken: amount,
            startTime: currentTime,
            lastClaimTime: currentTime + 12 * 30 days,
            vestingDuration: currentTime + 60 * 30 days,
            releaseInterval: 30 days,
            initialCliff: 12 * 30 days,
            phaseName: distributeInfo.name
        });
        advisorTokens.push(advisorToken);
    }

    function claimTeamandAdvisorToken(uint256 index) external {
        TokenVestingInfo storage advisor = advisorTokenData[msg.sender][index];
        uint256 currentTime = block.timestamp;
        require(
            currentTime > advisor.lastClaimTime + advisor.releaseInterval,
            "VESTING_PERIOD_INCOMPLETE"
        );
        require(advisor.remainingToken != 0, "ALL_TOKENS_CLAIMED");
        uint256 tokenClaimed;
        if (currentTime >= advisor.vestingDuration) {
            tokenClaimed = advisor.remainingToken;
            advisor.remainingToken = 0;
            advisor.lastClaimTime = advisor.vestingDuration;
        } else {
            uint256 totalClaim = (currentTime - advisor.lastClaimTime) /
                advisor.releaseInterval;
            tokenClaimed =
                ((advisor.SuuvoToken / 10000) *
                    _tokenDistributeData[3].releasePercentage) *
                totalClaim;
            advisor.lastClaimTime += totalClaim * advisor.releaseInterval;
            advisor.remainingToken -= tokenClaimed;
        }
        tokenContract.transfer(msg.sender, tokenClaimed);
    }

    function getTeamAndAdvisorUserList(
        address userAddress
    ) public view returns (TokenVestingInfo[] memory) {
        return advisorTokenData[userAddress];
    }

    function getAllAdvisorData()
        external
        view
        returns (TokenVestingInfo[] memory)
    {
        uint256 totalAdvisor;
        for (uint256 i = 0; i < _teamAndAdvisorList.length; i++) {
            totalAdvisor += advisorTokenData[_teamAndAdvisorList[i]].length;
        }
        TokenVestingInfo[] memory advisorData = new TokenVestingInfo[](
            totalAdvisor
        );
        uint256 index;
        for (uint256 i = 0; i < _teamAndAdvisorList.length; i++) {
            TokenVestingInfo[] storage advisorToken = advisorTokenData[
                _teamAndAdvisorList[i]
            ];
            for (uint256 j = 0; j < advisorToken.length; j++) {
                advisorData[index] = advisorToken[j];
                index++;
            }
        }
        return advisorData;
    }

    function MarketingandCSRToken(
        uint256 index,
        uint256 amount,
        address userAddress
    ) external onlyOwner {
        require(
            amount > 0 && userAddress != address(0),
            "INVALID_AMOUNT_OR_ADDRESS"
        );
        require(index == 6 || index == 7, "invalid index number");
        TokenVestingInfo[] storage MarketingandCSRTokens;
        if (index == 6) {
            MarketingandCSRTokens = MarketingTokenData[userAddress];
        } else {
            MarketingandCSRTokens = CSRTokenData[userAddress];
        }
        if (MarketingandCSRTokens.length == 0) {
            if (index == 6) {
                _marketingList.push(userAddress);
            } else {
                _CSRList.push(userAddress);
            }
        }
        TokenDistrubuteInfo storage distributeInfo = _tokenDistributeData[
            index
        ];
        require(
            distributeInfo.totalSuppliedToken + amount <
                distributeInfo.totalPhaseToken,
            "INSUFFICIENT_TOKENS_IN_PHASE"
        );
        uint256 currentTime = block.timestamp;
        distributeInfo.totalSuppliedToken += amount;
        TokenVestingInfo memory MarketingandCSR = TokenVestingInfo({
            beneficiary: userAddress,
            SuuvoToken: amount,
            remainingToken: amount,
            startTime: currentTime,
            lastClaimTime: currentTime + 12 * 30 days,
            vestingDuration: currentTime + 12 * 30 days,
            releaseInterval: 0,
            initialCliff: 0,
            phaseName: distributeInfo.name
        });
        MarketingandCSRTokens.push(MarketingandCSR);
    }

    function claimMarketingAndCSRToken(
        uint256 index,
        uint256 tokonomicsType
    ) external {
        require(index == 6 || index == 7, "invalid index number");
        TokenVestingInfo storage marketingAndCSR;
        if (tokonomicsType == 6) {
            marketingAndCSR = MarketingTokenData[msg.sender][index];
        } else {
            marketingAndCSR = CSRTokenData[msg.sender][index];
        }
        uint256 currentTime = block.timestamp;
        require(
            currentTime > marketingAndCSR.vestingDuration,
            "VESTING_PERIOD_INCOMPLETE"
        );
        require(marketingAndCSR.remainingToken != 0, "ALL_TOKENS_CLAIMED");
        marketingAndCSR.remainingToken = 0;
        tokenContract.transfer(msg.sender, marketingAndCSR.SuuvoToken);
    }

    function getMarketingUserList(
        address userAddress
    ) public view returns (TokenVestingInfo[] memory) {
        return MarketingTokenData[userAddress];
    }

    function getCSRUserList(
        address userAddress
    ) public view returns (TokenVestingInfo[] memory) {
        return CSRTokenData[userAddress];
    }

    function getAllMarketingData()
        external
        view
        returns (TokenVestingInfo[] memory)
    {
        uint256 totalMarketingUser;
        for (uint256 i = 0; i < _marketingList.length; i++) {
            totalMarketingUser += MarketingTokenData[_marketingList[i]].length;
        }
        TokenVestingInfo[] memory marketingData = new TokenVestingInfo[](
            totalMarketingUser
        );
        uint256 index;
        for (uint256 i = 0; i < _marketingList.length; i++) {
            TokenVestingInfo[] storage marketingToken = MarketingTokenData[
                _marketingList[i]
            ];
            for (uint256 j = 0; j < marketingToken.length; j++) {
                marketingData[index] = marketingToken[j];
                index++;
            }
        }
        return marketingData;
    }

    function getAllCSRData() external view returns (TokenVestingInfo[] memory) {
        uint256 totalCSR;
        for (uint256 i = 0; i < _CSRList.length; i++) {
            totalCSR += CSRTokenData[_CSRList[i]].length;
        }
        TokenVestingInfo[] memory CSRData = new TokenVestingInfo[](totalCSR);
        uint256 index;
        for (uint256 i = 0; i < _CSRList.length; i++) {
            TokenVestingInfo[] storage CSRToken = CSRTokenData[_CSRList[i]];
            for (uint256 j = 0; j < CSRToken.length; j++) {
                CSRData[index] = CSRToken[j];
                index++;
            }
        }
        return CSRData;
    }

    function claimContractToken(uint256 token) public onlyOwner {
        tokenContract.transfer(msg.sender, token);
    }

    function getTokonomicsData()
        public
        view
        returns (TokenDistrubuteInfo[] memory)
    {
        TokenDistrubuteInfo[] memory items = new TokenDistrubuteInfo[](8);
        for (uint256 i = 0; i < 8; ++i) {
            items[i] = _tokenDistributeData[i];
        }
        return items;
    }

    function getReserveData() public view returns (ReserveInfo[] memory) {
        return reserveDataInfo;
    }
}

// 0x17d7D7868b0cfF09351B187694B49a6385e371d6 - USDT
// 0x63431aD323c998eBd3BfB2C9117d717c6Fd51576 - Suuvo
