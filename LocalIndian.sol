pragma solidity ^0.5.10;

contract LocalIndianContract{
    
    event SignUpEvent(address indexed _newUser, uint indexed _userId, address indexed _sponsor, uint _sponsorId);
    event ReturnNodeToLocalEvent(address indexed _nodeReturn, uint indexed _userIdNodeReturn, address indexed _sponsor, uint _sponsorId);
    event NewVIPNodeEvent(address indexed _newNode, uint indexed _userId, address indexed _parentNode, uint _parentNodeId);
    event NewInitialWorldNodeEvent(address indexed _newNode, uint indexed _userId);
    event NewWorldNodeEvent(address indexed _newNode, uint indexed _userId, address indexed _parentNode, uint _parentNodeId);
    event PayBankInWorldEvent(address indexed _user, uint indexed _amount);
    event PayLocalEvent(address indexed _user, uint indexed _amount, address indexed _payer);
    event PayVIPEvent(address indexed _user, uint indexed _amount, address indexed _payer);
    event PayWorldEvent(address indexed _user, uint indexed _amount, address indexed _payer);
    
    enum activeIN { LocalMatrix, VIPMatrix, WorldMatrix }
    enum payType {VipPay, WorldPay, WalletPay}
    
    struct User {
        uint id;
        address sponsor;
        uint childPayedCount;
        activeIN activeUser;
        address nextLinked;
        bool isRoot;
        uint payVIP;
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
        
        User storage userNode = users[rootAddres];
        userNode.isRoot = true;
        userNode.id = nodeId++;
        userNode.activeUser = activeIN.LocalMatrix;
        
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
        if(walletCounterWaiting > 0) {
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
        walletPayCount++;
        if(walletPayCount == 5){
            walletCounterWaiting++;
            walletPayCount = 0;
        }
        emit PayLocalEvent(_sponsor, _payToSponsorLocal, _payer);
    }
    
    function loopVIP(address _newVIPNode) private {
        require(users[_newVIPNode].activeUser == activeIN.VIPMatrix, 'Invalid pass to VIPMatrix');
        emit NewVIPNodeEvent(_newVIPNode, users[_newVIPNode].id, users[_newVIPNode].sponsor, users[users[_newVIPNode].sponsor].id);
        recursiveVIP(_newVIPNode, users[_newVIPNode].sponsor);
    }

    function recursiveVIP(address _newVIPNode, address _sponsor) private{
        if(users[_sponsor].isRoot){
            PayUp(_sponsor, payToHeadVIP, _newVIPNode, payType.VipPay);
        }
        else if(users[_sponsor].activeUser == activeIN.VIPMatrix){
            users[_sponsor].payVIP +=1;
            if(users[_sponsor].payVIP == 2){
                users[_sponsor].activeUser = activeIN.WorldMatrix;
                users[_sponsor].payVIP = 0;
                loopWorld(_sponsor);
            }
            else{
                PayUp(_sponsor, payToHeadVIP, _newVIPNode, payType.VipPay);
            }
        }
        else{
            recursiveVIP(_newVIPNode, users[_sponsor].sponsor);
        }
    }  
    
    function loopWorld(address _newWorldNode) private {
        require(users[_newWorldNode].activeUser == activeIN.WorldMatrix, 'Invalid pass to WorldMatrix');        
        if(World.empty){
            World.empty = false;
            World.head = _newWorldNode;
            World.tail = _newWorldNode;
            emit NewInitialWorldNodeEvent(_newWorldNode, users[_newWorldNode].id);
            PayUp(rootAddres, payToHeadVIP, _newWorldNode, payType.WorldPay);
        }
        else{
            World.payToHead++;
            address temp =World.tail;
            users[World.tail].nextLinked = _newWorldNode;
            World.tail =  _newWorldNode;
            emit NewWorldNodeEvent(_newWorldNode, users[_newWorldNode].id, temp, users[temp].id);
            if(World.payToHead == 2){
                users[World.head].activeUser = activeIN.LocalMatrix;
                address temp2 = World.head;
                World.head = users[temp2].nextLinked;
                World.payToHead = 0;
                reMakeLoop(temp2);
            }
            else{
                PayUp(World.head,payToHeadWorld, _newWorldNode, payType.WorldPay);
            }
        }
    }
    
    function PayUp(address _sponsor, uint _amount, address _payer, payType _payType) private{
         if(!address(uint160(_sponsor)).send(_amount)){
             address(uint160(_sponsor)).transfer(_amount);
         }
         if(_payType == payType.VipPay){
            emit PayVIPEvent(_sponsor, _amount, _payer);
         }
         else if(_payType == payType.WorldPay){
            emit PayWorldEvent(_sponsor, _amount, _payer);
         }
         else{
            emit PayBankInWorldEvent(_sponsor, _amount); 
         }
    }
    
    function loopWorldWallet() private {
        if(walletCounterWaiting > 0){
            if((walletPayed % 3) == 1 || (walletPayed % 3) == 2){
                if(!World.empty){
                    World.payToHead++;
                    walletCounterWaiting--;
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
