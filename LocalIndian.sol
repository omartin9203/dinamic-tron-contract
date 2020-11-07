pragma solidity ^0.5.10;

contract LocalIndianContract{
    
    event SignUpEvent(address indexed _newUser, uint indexed _userId, address indexed _sponsor, uint _sponsorId);
    event ReturnNodeToLocalEvent(address indexed _nodeReturn, uint indexed _userIdNodeREturn, address indexed _sponsor, uint _sponsorId);
    event NewVIPNodeEvent(address indexed _newNode, uint indexed _userId, address indexed _parentNode, uint _parentNodeId);
    event NewiIntitialVIPNodeEvent(address indexed _newNode, uint indexed _userId);
    event NewiIntitialWorldNodeEvent(address indexed _newNode, uint indexed _userId);
    event NewWorldNodeEvent(address indexed _newNode, uint indexed _userId, address indexed _parentNode, uint _parentNodeId);
    event PayWalletInWorldEvent(address indexed _payable, uint indexed amount);
    event PayLocalEvent(address indexed _payable, uint indexed _amaount, address indexed payer);
    event PayVIPEvent(address indexed _payable, uint indexed _amaount, address indexed payer);
    event PayWorldEvent(address indexed _payable, uint indexed _amaount, address indexed payer);
    
    enum activeIN { LocalMatrix, VIPMatrix, WorldMatrix }
    enum payType {VIPPAy, WorldPay, WalletPay}
    
    struct User {
        uint id;
        address sponsor;
        uint childPayedCount;
        activeIN activeUser;
        address nextLinked;
        bool isRoot;
    }
    struct LinkedList{
        address head;
        address tail;
        uint payToHead;
        bool empty;
    }
    
    uint nodeId = 1;
    uint256 initialPay;
    uint payToSponsorLocal;
    uint payToHeadVIP;
    uint payToHeadWorld;
    uint minPayToHeadWorld;
    uint minNodesPayed;
    
    uint public walletPayCount;
    uint public walletCounterWaiting;
    uint public walletPayed;
    
    address payable rootAddres;
    address payable owner;
    
    mapping(address=>User) public users;
    
    LinkedList VIP;
    LinkedList World;
    
    
    
    modifier validNewUser(address _newUser) {
        uint32 size;
        assembly {
            size := extcodesize(_newUser)
        }
        require(size == 0, "The new user cannot be a contract");
        require(users[_newUser].id == 0, "This user already exists");
        _;
    }
    modifier restricted() {
        require(msg.sender == owner, "Restricted, only the creator of the contract");
        _;
    }
    
    constructor(address payable _rootAddres) public{
        rootAddres = _rootAddres;
        initialPay = 1000 trx;
        payToSponsorLocal = 200 trx;
        payToHeadVIP = 1000 trx;
        payToHeadWorld = 1000 trx;
        minPayToHeadWorld = 400 trx;
        minNodesPayed = 2;
        owner = msg.sender;
        
        walletPayCount = 0;
        walletCounterWaiting = 0;
        walletPayed = 0;
        
        User storage userNode = users[rootAddres];
        userNode.isRoot = true;
        userNode.id = nodeId++;
        userNode.activeUser = activeIN.LocalMatrix;
        
        VIP.empty = true;
        World.empty = true;
    }
    
    function() external payable {
        if(msg.data.length == 0) return signUp(msg.sender, rootAddres);
        address sponsor;
        bytes memory data = msg.data;
        assembly {
            sponsor := mload(add(data, 20))
        }
        signUp(msg.sender, sponsor);
    }
    
    function signUp(address _sponsor) external payable{
        // require(_sponsor != rootAddres, "You do not have permission to be a child of the root");
        signUp(msg.sender, _sponsor);
    }
    
    // function signUpAdmin(address _sponsor, address _newuser) external payable restricted{
    //     signUp(_sponsor, _newuser);
    // }
    
    function signUp(address payable _newUser, address _sponsor) private validNewUser(_newUser){
        require(users[_sponsor].id != 0, "This sponsor does not exists");
        require(msg.value == initialPay, 'You did not send the necessary amount' );
        
        User storage userNode = users[_newUser];
        userNode.id = nodeId++;
        userNode.sponsor = _sponsor;
        userNode.activeUser = activeIN.LocalMatrix;
        userNode.childPayedCount = 0; 
        emit SignUpEvent(_newUser, userNode.id, _sponsor,  users[_sponsor].id);
        localPay(_sponsor, payToSponsorLocal, _newUser);
        if(!users[_sponsor].isRoot){          
            makeLoop(_sponsor);
        }
    }
    
    function makeLoop(address _sponsor) private{         
        if(users[_sponsor].activeUser == activeIN.LocalMatrix && users[_sponsor].childPayedCount >= minNodesPayed){           
            users[_sponsor].activeUser = activeIN.VIPMatrix;
            users[_sponsor].childPayedCount -= minNodesPayed;
            loopVIP(_sponsor);        
        }
        if(walletPayCount == 5){
            walletCounterWaiting++;
            walletPayCount = 0;
            loopWorldWallet();
        }
    }

    function reMakeLoop(address _nodeReturned) private{
        emit ReturnNodeToLocalEvent(_nodeReturned, users[_nodeReturned].id, users[_nodeReturned].sponsor,  users[users[_nodeReturned].sponsor].id);
        localPay(users[_nodeReturned].sponsor, payToSponsorLocal, _nodeReturned);
        if(!users[users[_nodeReturned].sponsor].isRoot){           
            makeLoop(users[_nodeReturned].sponsor);
        }  
        makeLoop(_nodeReturned);
    }
    
    function localPay( address _sponsor, uint _payToSponsorLocal, address _payer) internal{
        if(users[_sponsor].isRoot){
            if(!address(uint160(_sponsor)).send(_payToSponsorLocal)){
                address(uint160(_sponsor)).transfer(_payToSponsorLocal);
            }
        }
        users[_sponsor].childPayedCount++;
        walletPayCount ++;
        emit PayLocalEvent(_sponsor, _payToSponsorLocal, _payer);
    }
    
    function loopVIP(address _newVIPNode) private {
        require(users[_newVIPNode].activeUser == activeIN.VIPMatrix, 'Invalid pass to VIPMatrix');        
        if(VIP.empty){
            VIP.empty = false;
            VIP.head = _newVIPNode;
            VIP.tail = _newVIPNode;
            emit NewiIntitialVIPNodeEvent(_newVIPNode, users[_newVIPNode].id);
            PayUp(rootAddres, payToHeadVIP, _newVIPNode, payType.VIPPAy);
        }
        else{
            VIP.payToHead += 1;
            address temp =VIP.tail;
            users[VIP.tail].nextLinked = _newVIPNode;
            VIP.tail =  _newVIPNode;
            emit NewVIPNodeEvent(_newVIPNode, users[_newVIPNode].id, temp, users[temp].id);
            if(VIP.payToHead == 2){
                users[VIP.head].activeUser = activeIN.WorldMatrix;
                address temp2 = VIP.head;
                VIP.head = users[temp2].nextLinked;
                VIP.payToHead = 0;
                loopWorld(temp2);
            }
            else{
                PayUp(VIP.head,payToHeadVIP,_newVIPNode, payType.VIPPAy);
            }
        }
    }
    
    function loopWorld(address _newWorlNode) private {
        require(users[_newWorlNode].activeUser == activeIN.WorldMatrix, 'Invalid pass to VIPMatrix');        
        if(World.empty){
            World.empty = false;
            World.head = _newWorlNode;
            World.tail = _newWorlNode;
            emit NewiIntitialWorldNodeEvent(_newWorlNode, users[_newWorlNode].id);
            PayUp(rootAddres, payToHeadVIP, _newWorlNode, payType.WorldPay);
        }
        else{
            World.payToHead += 1;
            address temp =World.tail;
            users[World.tail].nextLinked = _newWorlNode;
            World.tail =  _newWorlNode;
            emit NewWorldNodeEvent(_newWorlNode, users[_newWorlNode].id, temp, users[temp].id);
            if(World.payToHead == 2){
                users[World.head].activeUser = activeIN.LocalMatrix;
                address temp2 = World.head;
                World.head = users[temp2].nextLinked;
                World.payToHead = 0;
                reMakeLoop(temp2);
            }
            else{
                PayUp(World.head,payToHeadWorld, _newWorlNode, payType.WorldPay);
            }
        }
    }
    
    function PayUp(address _sponsor, uint _amount, address _payer, payType _payType) private{
         if(!address(uint160(_sponsor)).send(_amount)){
             address(uint160(_sponsor)).transfer(_amount);
         }
         if(_payType == payType.VIPPAy){
            emit PayVIPEvent(_sponsor, _amount, _payer);
         }
         else if(_payType == payType.WorldPay){
            emit PayWorldEvent(_sponsor, _amount, _payer);
         }
         else{
            emit PayWalletInWorldEvent(_sponsor, _amount ); 
         }
    }
    
    function loopWorldWallet() private {
        if(walletCounterWaiting > 0){
            if((walletPayed % 3) == 1 || (walletPayed % 3) == 2){
                if(!World.empty){
                    World.payToHead += 1;
                    walletCounterWaiting-=1;
                    walletPayed = (walletPayed + 1) % 3;
                    if(World.payToHead == 2){
                        if(World.tail == World.head){
                            World.empty = true;
                            users[World.head].activeUser = activeIN.LocalMatrix;
                            World.payToHead = 0;
                            reMakeLoop(World.head);
                        }
                        else{
                            users[World.head].activeUser = activeIN.LocalMatrix;
                            address temp2 = World.head;
                            World.head = users[temp2].nextLinked;
                            World.payToHead = 0;
                            reMakeLoop(temp2);
                        }
                    }
                    else{
                        PayUp(World.head, payToHeadWorld, rootAddres, payType.WalletPay);
                    }
                    loopWorldWallet();
                }
            }
            else{
                PayUp(rootAddres, payToHeadWorld, rootAddres, payType.WalletPay);
                walletCounterWaiting-=1;
                walletPayed = (walletPayed + 1) % 3;
                loopWorldWallet();
            }
        }
    }
  
    function withdrawLostTRXFromBalance() public restricted {
        address(uint160(owner)).transfer(address(this).balance);
    }
}