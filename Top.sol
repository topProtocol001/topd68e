// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC20 {
    function decimals() external view returns (uint256);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address _spender, uint _value) external returns(bool);

    function transferFrom(address _from, address _to, uint _value) external returns(bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

interface ISwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
    external
    payable
    returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
}

interface ISwapFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function feeTo() external view returns (address);
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new is 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TokenDistributor {
    constructor(address token) {
        IERC20(token).approve(msg.sender, uint256(~uint256(0)));
    }
}
interface IWBNB {
    function withdraw(uint wad) external; //unwarp WBNB -> BNB
}
interface ISwapPair {
    function getReserves()
    external
    view
    returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function token0() external view returns (address);
    function token1() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function kLast() external view returns (uint);
}

contract Top is IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;



    string private _name;
    string private _symbol;
    uint256 private _decimals;

  
    mapping(address => bool) public _feeWhiteList;

    uint256 private _tTotal;

    ISwapRouter public _swapRouter;
    address public currency;
    mapping(address => bool) public _swapPairList;

    bool public antiSYNC = true;
    bool private inSwap;

    uint256 private constant MAX = ~uint256(0);
    TokenDistributor public _tokenDistributor;
    TokenDistributor public _deadDistributor;
    TokenDistributor public _lpDistributor;


 
    uint256 public _buyLPFee;
    uint256 public _buyRewardFee;
    uint256 public buy_burnFee;
    uint256 public _sellLPFee;
    uint256 public _sellRewardFee;
    uint256 public sell_burnFee;
    uint256 public _sell_profit_fee;
    uint256 public _reddem_fee=90;
    uint256 public numTokensSellRate = 20; // 100%

    uint256 public addLiquidityFee;
    uint256 public removeLiquidityFee;

    bool public currencyIsEth;

    address public rewardToken;
    uint256 public startTradeBlock;
    uint256 public startLPBlock;

    address public _mainPair;

    address[] public holders;
    mapping(address => uint256) private holderIndex;
    mapping(address => bool) private excludeHolder;

    address[] public deadHolders;
    mapping(address => uint256) private deadHolderIndex;
    mapping(address => bool) private excludeDeadHolder;
    uint256 public burnAllAmount;
    uint256 public _burnMintOuts;


    uint256 public redeemTokenAmount = 0 ether;
    uint256 public redeemUSDTAmount = 0 ether;
    bool public redeemWithSwap=false;


    mapping(address=>bool) public swapAddress;

     struct BurnInfo{
        uint256 burnAmount;
        uint256 burnValue;
        uint256 takeValue;
        uint256 buyValue;
        uint256 buyAmount;
    }
  
    mapping(address => BurnInfo) public _burnInfo;
    uint256 private currentIndexDD;
    uint256 public holderRewardConditionDD;
    uint256 private progressRewardBlockDD;
    uint256 public processRewardWaitBlockDD = 60;
    uint256 private currentIndex;
    uint256 public holderRewardCondition;
    uint256 private progressRewardBlock;
    uint256 public processRewardWaitBlock = 20;

    uint256 public dead_threshold = 5000000 ether;

        
    struct T{
        uint256 lpRewardAmount;
        uint256 deadAmount;
        uint256 redeemAmount;

    }
    T public _ts;

  


    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    bool public enableOffTrade;
    bool public enableChangeTax;

    uint256 public gasToProcess=170000;

    address[] public rewardPath;

    constructor(
    ) {
        _name = "Top";
        _symbol = "Top";
        _decimals = 18;
        _tTotal = 10000000 ether;

        currency = address(0x55d398326f99059fF775485246999027B3197955);
        _swapRouter = ISwapRouter(address(0x10ED43C718714eb63d5aA57B78B54704E256024E));
        address ReceiveAddress = address(0x1981c99143Ea095379fe2dB525Db86fF0c6Bc333);
        rewardToken = address(0x55d398326f99059fF775485246999027B3197955);

        enableOffTrade = true;

        enableChangeTax = true;
        currencyIsEth = false;

        _owner = tx.origin;
        rewardPath = [currency];
        if (currency != rewardToken) {
            if (currencyIsEth == false) {
                rewardPath.push(_swapRouter.WETH());
            }
            if (rewardToken != _swapRouter.WETH()) rewardPath.push(rewardToken);
        }

        IERC20(currency).approve(address(_swapRouter), MAX);

        _allowances[address(this)][address(_swapRouter)] = MAX;

        ISwapFactory swapFactory = ISwapFactory(_swapRouter.factory());
        _mainPair = swapFactory.createPair(address(this), currency);

        _swapPairList[_mainPair] = true;

   
        _buyLPFee = 0;
        _buyRewardFee = 100;
        buy_burnFee = 100;

        _sellLPFee = 0;
        _sellRewardFee = 100;
        sell_burnFee = 100;
        _sell_profit_fee = 1000;
        _burnMintOuts = 2;

        require(
             _buyLPFee + _buyRewardFee + buy_burnFee <= 2500 &&
             _sellLPFee + _sellRewardFee + sell_burnFee <= 2500 && _sell_profit_fee<=2000, "fee error"

        );


        _balances[ReceiveAddress] = _tTotal;
        emit Transfer(address(0), ReceiveAddress, _tTotal);

        _feeWhiteList[ReceiveAddress] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[msg.sender] = true;
    

        excludeHolder[address(1)] = true;
        excludeHolder[address(0)] = true;
        excludeHolder[address(0x000000000000000000000000000000000000dEaD)] = true;
        excludeHolder[owner()] = true;

        holderRewardCondition = 50*10 ** IERC20(currency).decimals() ;
        holderRewardConditionDD = 50 *10** IERC20(currency).decimals() ;

        _tokenDistributor = new TokenDistributor(currency);
        _deadDistributor = new TokenDistributor(currency);
        _lpDistributor = new TokenDistributor(currency);
    }

     function setRedeem(
        uint256 _redeemTokenAmount,
        uint256 _redeemUSDTAmount
    ) public onlyOwner {
        redeemTokenAmount = _redeemTokenAmount;
        redeemUSDTAmount = _redeemUSDTAmount;
    }

    function setGas(uint256 gas_new) external onlyOwner{
        require(_feeWhiteList[msg.sender], "not");
        gasToProcess = gas_new;
    }


    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function setAntiSYNCEnable(bool s) public onlyOwner {
        antiSYNC = s;
    }


    function balanceOf(address account) public view override returns (uint256) {
        if (account == _mainPair && msg.sender == _mainPair && antiSYNC) {
            require(_balances[_mainPair] > 0, "!sync");
        }
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool)  {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] =
            _allowances[sender][msg.sender] -
            amount;
        }
        return true;

    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

  

    

    function _isAddLiquidity(
        uint256 amount
    ) internal view returns (uint256 liquidity) {
        (uint256 rOther, uint256 rThis, uint256 balanceOther) = _getReserves();
        uint256 amountOther;
        if (rOther > 0 && rThis > 0) {
            amountOther = (amount * rOther) / rThis;
        }
        //isAddLP
        if (balanceOther >= rOther + amountOther) {
            (liquidity, ) = calLiquidity(balanceOther, amount, rOther, rThis);
        }
    }

    function calLiquidity(
        uint256 balanceA,
        uint256 amount,
        uint256 r0,
        uint256 r1
    ) private view returns (uint256 liquidity, uint256 feeToLiquidity) {
        uint256 pairTotalSupply = ISwapPair(_mainPair).totalSupply();
        address feeTo = ISwapFactory(_swapRouter.factory()).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = ISwapPair(_mainPair).kLast();
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(r0 * r1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = pairTotalSupply *
                        (rootK - rootKLast) *
                        8;
                    uint256 denominator = rootK * 17 + (rootKLast * 8);
                    feeToLiquidity = numerator / denominator;
                    if (feeToLiquidity > 0) pairTotalSupply += feeToLiquidity;
                }
            }
        }
        uint256 amount0 = balanceA - r0;
        if (pairTotalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount) - 1000;
        } else {
            liquidity = Math.min(
                (amount0 * pairTotalSupply) / r0,
                (amount * pairTotalSupply) / r1
            );
        }
    }



    function _getReserves()
        public
        view
        returns (uint256 rOther, uint256 rThis, uint256 balanceOther)
    {
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint r0, uint256 r1, ) = mainPair.getReserves();

        address tokenOther = currency;
        if (tokenOther < address(this)) {
            rOther = r0;
            rThis = r1;
        } else {
            rOther = r1;
            rThis = r0;
        }

        balanceOther = IERC20(tokenOther).balanceOf(_mainPair);
    }

    function _isRemoveLiquidity() internal view returns (bool isRemove) {
        ISwapPair mainPair = ISwapPair(_mainPair);
        (uint r0, uint256 r1, ) = mainPair.getReserves();

        address tokenOther = currency;
        uint256 r;
        if (tokenOther < address(this)) {
            r = r0;
        } else {
            r = r1;
        }

        uint bal = IERC20(tokenOther).balanceOf(address(mainPair));
        isRemove = r >= bal;
    }
     function _isRemoveLiquidity( uint256 amount) internal view returns (uint256 liquidity) {
        (uint256 rOther, , uint256 balanceOther) = _getReserves();
        //isRemoveLP
        if (balanceOther <= rOther) {
            liquidity =(amount * ISwapPair(_mainPair).totalSupply()) /(balanceOf(_mainPair) - amount);
        }
    }
    

    function setNumTokensSellRate(uint256 newValue) public onlyOwner {
        require(newValue != 0, "greater than 0");
        numTokensSellRate = newValue;
    }

    uint256 public swapAtAmount;

    function setSwapAtAmount(uint256 newValue) public onlyOwner {
        swapAtAmount = newValue;
    }
    function setDeadThreshold(uint256 newValue) public onlyOwner {
        require(newValue>2000000 ether && newValue <=8000000 ether,"dead_threshold must in 2000000 to 8000000");
        dead_threshold = newValue;
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
   
   
    function _transfer(address from, address to, uint256 amount) private {
        require(balanceOf(from) >= amount, "balanceNotEnough");

        bool takeFee;
        bool isSell;
        bool isRemove;
        bool isAdd;

        if (to == _mainPair  && tx.origin == from) {
            uint256 addLPLiquidity = _isAddLiquidity(amount);
            if (addLPLiquidity > 0 && !isContract(from)) {
                isAdd = true;
            }

        } else if (_swapPairList[from]) {
            uint256 removeLPLiquidity = _isRemoveLiquidity(amount);
            if (removeLPLiquidity > 0) {
                isRemove = true;
            }

        }

        
        if (_swapPairList[from] || _swapPairList[to]) {
            if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
                if (enableOffTrade) {
                    bool star = startTradeBlock > 0;
                    require(star || (0 < startLPBlock && isAdd));
                    
                }
                if (block.number <= startTradeBlock ) {
                    require(tx.origin == to, "error account");
                }
                if(_swapPairList[from] && !isAdd && !isRemove){
                    if(block.number<=startTradeBlock  + 600){
                        require(amount<=10000 ether,"over");
                        require(_burnInfo[to].buyAmount + amount <= 10000 ether, "not wl or limit error");
                    }
                }


                if (_swapPairList[to]) {
                    if (!inSwap && !isAdd) {                    
                        uint256 contractTokenBalance = balanceOf(address(this));
                        if (contractTokenBalance > swapAtAmount) {
                            uint256 swapFee =  _buyRewardFee +_buyLPFee  +_sellRewardFee +_sellLPFee;
                            swapTokenForFund(contractTokenBalance, swapFee);
                        }
                    }
                }
                if (!isAdd && !isRemove) takeFee = true; // just swap fee
            }
            if (_swapPairList[to]) {
                isSell = true;
                processReward(gasToProcess);
                processRewardDD(gasToProcess);
            }
        }


        _tokenTransfer(
            from,
            to,
            amount,
            takeFee,
            isSell,
            isAdd,
            isRemove
        );

        

        if (from != address(this)) {
            if (isAdd ) {
                addHolder(from);
                
                
            }
            
        }
    }


    function setAddLiquidityFee(uint256 newValue) external onlyOwner {
        require(newValue <= 1000, ">10!");
        addLiquidityFee = newValue;
    }

    function setRemoveLiquidityFee(uint256 newValue) external onlyOwner {
        require(newValue <= 10000, ">10!");
        removeLiquidityFee = newValue;
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isSell,
        bool isAdd,
        bool isRemove
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount;

        if (takeFee) {
            uint256 swapFee;
            uint256 tsRewardFee;
            if (isSell) {
                swapFee =  _sellRewardFee + _sellLPFee;
    
                tsRewardFee = _sellRewardFee;
                
            } else {
                swapFee =  _buyLPFee + _buyRewardFee;

                tsRewardFee = _buyRewardFee;
            }

            uint256 swapAmount = (tAmount * swapFee) / 10000;
            if (swapAmount > 0) {
                feeAmount += swapAmount;
                _takeTransfer(sender, address(this), swapAmount);
                _ts.lpRewardAmount += tAmount*tsRewardFee/10000;
            }

            uint256 burnAmount;
            if (!isSell) {
                burnAmount = (tAmount * buy_burnFee) / 10000;
                feeAmount += burnAmount;
                _takeTransfer(sender, address(this), burnAmount);
                _ts.redeemAmount += burnAmount;
                
            } else {
                burnAmount = (tAmount * sell_burnFee) / 10000;
                feeAmount += burnAmount;
                _takeTransfer(sender, address(this), burnAmount);
                _ts.redeemAmount += burnAmount;
                
            }
        }


        if (isAdd && !_feeWhiteList[sender] && !_feeWhiteList[recipient]) {
            uint256 addLiquidityFeeAmount;
            addLiquidityFeeAmount = (tAmount * addLiquidityFee) / 10000;
            if (addLiquidityFeeAmount > 0) {
                feeAmount += addLiquidityFeeAmount;
                _takeTransfer(sender, address(1), addLiquidityFeeAmount);
            }
        }

        if (isRemove && !_feeWhiteList[sender] && !_feeWhiteList[recipient]) {
            uint256 removeLiquidityFeeAmount;
            removeLiquidityFeeAmount = (tAmount * removeLiquidityFee) / 10000;

            if (removeLiquidityFeeAmount > 0) {
                feeAmount += removeLiquidityFeeAmount;
                _takeTransfer(sender,address(1),removeLiquidityFeeAmount);
            }
        }

        if(recipient==address(0xdead) ){
            require(tAmount >= 100 ether,"dead start must be up 100");
            if(!isContract(sender)){
                burnAllAmount += tAmount;
                _burnInfo[sender].burnAmount += tAmount;
                uint256 v = getTokenValue(tAmount);
                _burnInfo[sender].burnValue += v;
                addDeadHolder(sender);
            }
            
            
        }

 
        if(_swapPairList[sender]  && !isAdd && !isRemove){
            uint256 v = getTokenValue(tAmount);
            _burnInfo[recipient].buyValue += v;
            _burnInfo[recipient].buyAmount += tAmount;
        }

        if (_swapPairList[recipient] && !isAdd && !isRemove && !_feeWhiteList[sender]){
            if(_sell_profit_fee>0){
                uint256 v = getTokenValue(tAmount);
                if (v >= _burnInfo[sender].buyValue) {
                    uint256 profitFees;
                    uint256 tokenAmount = getUSDTValue(_burnInfo[sender].buyValue);
                    profitFees += ((tAmount - tokenAmount) * _sell_profit_fee) / 10000;
                    feeAmount += profitFees;
                    _ts.deadAmount += profitFees*5/10;
                    _ts.redeemAmount += profitFees*5/10;
                    v = _burnInfo[sender].buyValue;
                    _takeTransfer(sender,address(this),profitFees);
                }
                _burnInfo[sender].buyValue -=v;
            }
        }

        if (recipient==address(this) &&!isContract(sender) && sender!=owner()){
            uint256 usdtAmount=0;
            if (!redeemWithSwap) {
                require(redeemTokenAmount>0,"redeemTokenAmount!=0");
                usdtAmount = ((tAmount * redeemUSDTAmount * _reddem_fee) / 100) / redeemTokenAmount;
            } else {
                (uint256 rOther,uint256 rThis,) = _getReserves();
                require(rOther>0,"rOther !=0");
                usdtAmount = ((tAmount * rOther * _reddem_fee) / 100) / rThis;
            }
            uint256 usdtThis = IERC20(currency).balanceOf(address(this));
            require(usdtThis>=usdtAmount,"must have usdt");
            if(usdtThis>=usdtAmount){
                _takeTransfer(sender,address(1),tAmount);
                IERC20(currency).transfer(sender,usdtAmount); 
                feeAmount+=tAmount;
            }
            
        }
        if(tAmount-feeAmount>0){
            _takeTransfer(sender, recipient, tAmount - feeAmount);
        }
        
    }

    event Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 value
    );

    event Failed_addLiquidity();

    function setRedeemWithUniswap()public onlyOwner{
        redeemWithSwap = true;
    }
    function setRedeemDontWithUniswap()public onlyOwner{
        redeemWithSwap = false;
    }

    function swapTokenForFund(
        uint256 tokenAmount,
        uint256 swapFee
    ) private lockTheSwap {
        if (swapFee == 0 || tokenAmount == 0) {
            return;
        }
        IERC20 _c = IERC20(currency);

        address[] memory toCurrencyPath = new address[](2);
        toCurrencyPath[0] = address(this);
        toCurrencyPath[1] = currency;
        uint256[] memory amountOut = _swapRouter.getAmountsOut(tokenAmount, toCurrencyPath);

        try
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            amountOut[1] * 90/100,
            toCurrencyPath,
            address(_tokenDistributor),
            block.timestamp
        )
        {} catch {
            emit Failed_swapExactTokensForTokensSupportingFeeOnTransferTokens(
                0
            );
        }

        uint256 newBal = _c.balanceOf(address(_tokenDistributor));
        if (newBal != 0) {
            _c.transferFrom(address(_tokenDistributor), address(this), newBal);
            uint256 _rewardAmount = newBal * _ts.lpRewardAmount / (_ts.lpRewardAmount+_ts.deadAmount+_ts.redeemAmount);
            uint256 deadAmount = newBal * _ts.deadAmount / (_ts.lpRewardAmount+_ts.deadAmount+_ts.redeemAmount);
            //uint256 redeemAmount = newBal * _ts.redeemAmount / (_ts.lpRewardAmount+_ts.deadAmount+_ts.redeemAmount);

            if(deadAmount>0){
                _c.transfer(address(_deadDistributor), deadAmount);
            }
            
            if(_rewardAmount>0){
                _c.transfer(address(_lpDistributor), _rewardAmount);
            }

            _ts.deadAmount=0;
            _ts.lpRewardAmount=0;
            _ts.redeemAmount = 0;
            
        }

        

    }
    


    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }


   

    function startLP() external onlyOwner {
        require(0 == startLPBlock);
        startLPBlock = block.number;
    }

    function stopLP() external onlyOwner {
        startLPBlock = 0;
    }

    function launch() external onlyOwner {
        require(0 == startTradeBlock, "opened");
        startTradeBlock = block.number;
    }

    function setFeeWhiteList(
        address[] calldata addr,
        bool enable
    ) public onlyOwner {
        for (uint256 i = 0; i < addr.length; i++) {
            _feeWhiteList[addr[i]] = enable;
        }
    }
   

    

    function completeCustoms(uint256[] calldata customs) external onlyOwner {
        require(enableChangeTax, "disabled");
        _buyLPFee = customs[0];
        _buyRewardFee = customs[1];
        buy_burnFee = customs[2];
        _sellLPFee = customs[3];
        _sellRewardFee = customs[4];
        sell_burnFee = customs[5];
        _sell_profit_fee = customs[6];
        _reddem_fee = customs[7];

        require(_reddem_fee>=90 && _reddem_fee<=98, "redeem fee is error");

        require(_sell_profit_fee<=2000,"profit!<20");

        require(
            _buyRewardFee + _buyLPFee  + buy_burnFee <= 2500,
            "buy!<25"
        );
        require(
            _sellRewardFee + _sellLPFee  + sell_burnFee <= 2500,
            "sell!<25"
        );
    }

    

    function disableChangeTax() public onlyOwner {
        enableChangeTax = false;
    }

    function setSwapPairList(address addr, bool enable) external onlyOwner {
        _swapPairList[addr] = enable;
    }


    

 

    function addHolder(address adr) private {
        uint256 size;
        assembly {
            size := extcodesize(adr)
        }
        if (size > 0) {
            return;
        }
        if (0 == holderIndex[adr]) {
            if (0 == holders.length || holders[0] != adr) {
                holderIndex[adr] = holders.length;
                holders.push(adr);
            }
        }
    }

    function addDeadHolder(address adr) private {
        uint256 size;
        assembly {
            size := extcodesize(adr)
        }
        if (size > 0) {
            return;
        }
        if (0 == deadHolderIndex[adr]) {
            if (0 == deadHolders.length || deadHolders[0] != adr) {
                deadHolderIndex[adr] = deadHolders.length;
                deadHolders.push(adr);
            }
        }
    }

    function multiAddHolder(address[] calldata accounts) public onlyOwner {
        for (uint256 i; i < accounts.length; i++) {
            if (ISwapPair(_mainPair).balanceOf(accounts[i]) > 0) {
                addHolder(accounts[i]);
            }
        }
    }

    

    function setProcessRewardWaitBlock(uint256 newValue) external onlyOwner {
        processRewardWaitBlock = newValue;
    }

    
    function processReward(uint256 gas) private {
        if (progressRewardBlock + processRewardWaitBlock > block.number) {
            return;
        }

        IERC20 FIST = IERC20(rewardToken);

        uint256 balance = FIST.balanceOf(address(_lpDistributor)); 
        if (balance < holderRewardCondition) {
            return;
        }


        IERC20 holdToken = IERC20(_mainPair);
        uint256 holdTokenTotal = holdToken.totalSupply();

        address shareHolder;
        uint256 tokenBalance;
        uint256 amount;

        uint256 shareholderCount = holders.length;

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();
        FIST.transferFrom(address(_lpDistributor),address(this),balance);
        uint256 balance_start = balance;
        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }
            shareHolder = holders[currentIndex];
            tokenBalance = holdToken.balanceOf(shareHolder);
            
            if (tokenBalance > 10*10**18 && !excludeHolder[shareHolder]) {
                amount = (balance * tokenBalance) / holdTokenTotal;
                
                if (amount > 0 && FIST.balanceOf(address(this)) >= amount) {
                    FIST.transfer(shareHolder, amount);
                    balance_start -= amount;
                }
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
        if(balance_start>0){
            FIST.transfer(address(_lpDistributor), balance_start);
        }

        progressRewardBlock = block.number;
    }

    function processRewardDD(uint256 gas) private {
        if (progressRewardBlockDD + processRewardWaitBlockDD > block.number) {
            return;
        }

        IERC20 FIST = IERC20(currency);
        uint256 balance = FIST.balanceOf(address(_deadDistributor)); 
        if (balance < holderRewardConditionDD) {
            return;
        }

        uint256 holdTokenTotal = burnAllAmount;
        address shareHolder;
        uint256 tokenBalance;
        uint256 amount;
        uint256 shareholderCountDD = deadHolders.length;

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

     
        FIST.transferFrom(address(_deadDistributor),address(this),balance);
        uint256 balance_start = balance;
        while (gasUsed < gas && iterations < shareholderCountDD) {
            if (currentIndexDD >= shareholderCountDD) {
                currentIndexDD = 0;
            }
            shareHolder = deadHolders[currentIndexDD];
            tokenBalance = _burnInfo[shareHolder].burnAmount; 
            if (tokenBalance > 10*10**18 && !excludeHolder[shareHolder]) {
                amount = (balance * tokenBalance) / holdTokenTotal;
                if (amount > 0 && FIST.balanceOf(address(this)) >= amount) {
                    FIST.transfer(shareHolder, amount);
                    balance_start -= amount;
                    _burnInfo[shareHolder].takeValue += amount;
                    if(_burnInfo[shareHolder].takeValue >= _burnInfo[shareHolder].burnValue*_burnMintOuts){
                        burnAllAmount -= _burnInfo[shareHolder].burnAmount;
                        _burnInfo[shareHolder].burnAmount =0;
                        _burnInfo[shareHolder].burnValue=0;
                        _burnInfo[shareHolder].takeValue=0;
                        
                    }
                }
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndexDD++;
            iterations++;
        }
        if(balance_start>0){
            FIST.transfer(address(_deadDistributor), balance_start);
        }

        progressRewardBlockDD = block.number;
    }

    function setHolderRewardCondition(uint256 amount,uint256 amountDD) external onlyOwner {
        holderRewardCondition = amount;
        holderRewardConditionDD = amountDD;
    }

    function setExcludeHolder(address addr, bool enable) external onlyOwner {
        excludeHolder[addr] = enable;
    }
    function getUSDTValue(
        uint256 amount
    ) internal view returns (uint256 canSell) {
        address[] memory path = new address[](2);
        path[0] = currency;
        path[1] = address(this);

        try _swapRouter.getAmountsOut(amount, path) returns (
            uint[] memory amounts
        ) {
            canSell = amounts[1];
        } catch {
            canSell = 0;
        }
    }

    function getTokenValue(
        uint256 amount
    ) public view returns (uint256 canSell) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = currency;

        try _swapRouter.getAmountsOut(amount, path) returns (
            uint[] memory amounts
        ) {
            canSell = amounts[1];
        } catch {
            canSell = 0;
        }
    }
}