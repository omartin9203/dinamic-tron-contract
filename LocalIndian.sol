pragma solidity ^0.5.10;

contract LocalIndianContract{
     event SignUpEvent(address indexed _newUser, uint indexed _userId, address indexed _sponsor, uint _sponsorId);
     event NewVIPNodeEvent(address indexed _newNode, uint indexed _userId, address indexed _parentNode, uint _parentNodeId);
     event NewiIntitialVIPNodeEvent(address indexed _newNode, uint indexed _userId);
     event NewWorldNodeEvent(address indexed _newNode, uint indexed _userId, address indexed _parentNode, uint _parentNodeId);
     event ActivatedWorldEvent(uint indexed _newWallet);
     event NewWalletInWorldEvent(uint indexed _newWallet);
    
    enum activeIN { LocalMatrix, VIPMatrix, WorldMatrix }
    
    struct User {
        uint id;
        address sponsor;
        uint childNodes;
        uint childPayedCount;
        uint contractMony;
        activeIN activeUser;
        // estos son parametros de  LinkedList
        address nextLinked;
        uint nextLinkedIdWallet;
        bool isWalletnextLinked;
        bool isRoot;
    }
    struct Wallet {
        uint id;
        uint payCount;
        uint contractMony;
        address nextLinked;
        bool isWalletNext;
        uint nextLinkedWallet;
    }
    struct LinkedList{
        uint length;
        address head;
        address tail;
        uint payToHead;
        bool empty;
        
        bool isWalletHead;
        bool isWallettail;
        uint headWallet;
        uint tailwallet;
    }
    
    uint nodeId = 1;
    uint walletId=1;
    uint initialPay;
    uint payToSponsorLocal;
    uint payToHeadVIP;
    uint payToHeadWorld;
    uint minNodesPayed;
    
    bool emptyWorld;
    
    address payable walletPrincipal;
    address payable rootAddres;
    
    mapping(address=>User) public users;
    mapping(uint => Wallet) wallets;
    
    LinkedList VIP;
    LinkedList World;
    
    constructor(address payable _walletLoop, address payable _rootAddres) public{
        walletPrincipal = _walletLoop;
        rootAddres = _rootAddres;
        minNodesPayed = 2;
        
        User storage userNode = users[rootAddres];
        userNode.isRoot = true;
        userNode.activeUser = activeIN.LocalMatrix;
        
        makeWallet(walletId);
        
        VIP.length = 0;
        VIP.empty = true;
        // VIP.head = rootAddres;
        // VIP.tail = rootAddres;
        //revisar que las listas esten vacias o no antes de hacer nada
    }
    
    function signUp(address _sponsor) external payable{
        signUp(msg.sender, _sponsor);
    }
    
    function signUp(address payable _newUser, address _sponsor) private{
        require(msg.value == initialPay, 'Didint have necsary funds' );
        
        User storage userNode = users[_newUser];
        userNode.id = nodeId++;
        userNode.sponsor = _sponsor;
        userNode.childNodes = 0;
        userNode.contractMony = msg.value;
        userNode.activeUser = activeIN.LocalMatrix;
        userNode.childPayedCount = 0; 
        if(!users[_sponsor].isRoot){
            emit SignUpEvent(_newUser, userNode.id, _sponsor,  users[_sponsor].id);
            makeLoop(_newUser, _sponsor);
        }
        else{
            emit SignUpEvent(_newUser, userNode.id, _sponsor,  users[_sponsor].id);
            localPay(_newUser, _sponsor);
        }
    }
    
    function makeLoop(address _from, address _sponsor) private{
        if(users[_sponsor].activeUser == activeIN.LocalMatrix){
            localPay(_from, _sponsor);
            if(users[_sponsor].childPayedCount >= minNodesPayed){
                users[_sponsor].activeUser = activeIN.VIPMatrix;
                users[_sponsor].childPayedCount -= minNodesPayed;
                loopVIP(_sponsor);
            }
        }
        else{
            wallets[walletId].contractMony = payToSponsorLocal*2;
            wallets[walletId].payCount +=2;
            
            users[_sponsor].childNodes++;//ESTO VARIA SEGUN LA DUDA DE A QUIEN SE LE PAGA CUANDO NO ESTA ACTIVO EN LA LOCAL
            //pagalo todo a la wallet y por fin que es lo que cuenta aqui???
            // cuenta el pago doble a la wallet o simple??
        }
        if(wallets[walletId].payCount == 5){
            loopWorldWallet(walletId);
            makeWallet(walletId++);
        }
    }
    function localPay(address _from, address _sponsor) internal{
        if(users[_sponsor].isRoot){
            if(!address(uint160(_sponsor)).send(payToSponsorLocal)){
                address(uint160(_sponsor)).transfer(payToSponsorLocal);
            }
        }
        else{
            users[_sponsor].contractMony += payToSponsorLocal;
        }
        users[_sponsor].childNodes++;
        users[_sponsor].childPayedCount++;
        wallets[walletId].contractMony = payToSponsorLocal;
        wallets[walletId].payCount ++;
        users[_from].contractMony -= (payToSponsorLocal*2);
    }
    
    function loopVIP(address _newVIPNode) private {
        VIP.payToHead += 1;
        VIP.length +=1;
        if(VIP.empty){
            VIP.empty = false;
            VIP.head = _newVIPNode;
            VIP.tail = _newVIPNode;
            emit NewiIntitialVIPNodeEvent(_newVIPNode, users[_newVIPNode].id);
            VIPPay(_newVIPNode, rootAddres);
        }
        else{
            address temp =VIP.tail;
            users[VIP.tail].nextLinked = _newVIPNode;
            VIP.tail =  _newVIPNode;
            emit NewVIPNodeEvent(_newVIPNode, users[_newVIPNode].id, temp, users[temp].id);
            if(VIP.payToHead == 2){
                users[VIP.head].contractMony += payToHeadVIP;//*********en estas dos lineas efectuo el pago de manera interna
                users[_newVIPNode].contractMony -= payToHeadVIP;
                users[VIP.head].activeUser = activeIN.WorldMatrix;
                address temp2 = VIP.head;
                VIP.head = users[temp2].nextLinked;
                VIP.payToHead = 0;
                loopWorld(temp2);
            }
            else{
                VIPPay(_newVIPNode, VIP.head);
            }
        }
    }
    
    function VIPPay(address _from, address _sponsor) private{
         if(!address(uint160(_sponsor)).send(payToHeadVIP)){
             address(uint160(_sponsor)).transfer(payToHeadVIP);
         }
         users[_from].contractMony -=payToHeadVIP;
    }
    
    function loopWorld(address _backLocalNode) private {
        require(!emptyWorld, 'Sorry!, this matrix is not initialize!');
        
        World.payToHead += 1;
        World.length+=1;
        if(World.isWallettail){
            wallets[World.tailwallet].isWalletNext =  false;
            wallets[World.tailwallet].nextLinked = _backLocalNode;
            World.isWallettail = false;
            World.tail = _backLocalNode;
        }
        else{
            address temp =World.tail;
            users[World.tail].nextLinked = _backLocalNode;
            World.tail =  _backLocalNode;
            emit NewWorldNodeEvent(_backLocalNode, users[_backLocalNode].id, temp, users[temp].id);
        }
        if(World.payToHead == 2){
              if(World.isWalletHead){
                worldPayWallets(_backLocalNode, rootAddres, false);
                if(wallets[World.headWallet].isWalletNext){
                    World.headWallet = wallets[World.headWallet].nextLinkedWallet;
                }
                else{
                    World.isWalletHead = false;
                    World.head = wallets[World.headWallet].nextLinked;
                }
              }
              else{
                worldPayWallets(_backLocalNode, World.head, false);
                users[World.head].activeUser = activeIN.LocalMatrix;
                address temp2 = World.head;
                if(users[temp2].isWalletnextLinked){
                    World.isWalletHead = true;
                    World.headWallet = users[temp2].nextLinkedIdWallet;
                }
                else{
                    World.head = users[World.head].nextLinked;
                }
                makeLoop(users[temp2].sponsor, temp2);
              }
            World.payToHead = 0;
            World.length -=1;
        }
    }
    
    function loopWorldWallet(uint _walletId) private {
        if(emptyWorld){
            emptyWorld = false;
            World.headWallet = _walletId;
            World.isWalletHead = true;
            worldPayWallets(rootAddres, rootAddres, World.isWallettail);
            emit ActivatedWorldEvent(World.headWallet);
        }
        else{
            if(World.isWallettail){
                wallets[World.tailwallet].isWalletNext = true;
                uint temp = World.tailwallet;
                wallets[temp].nextLinkedWallet = World.tailwallet;
                emit NewWalletInWorldEvent(World.tailwallet);
            }
            else{
                 users[World.tail].isWalletnextLinked = true;
                 users[World.tail].nextLinkedIdWallet = World.tailwallet;
                 emit NewWalletInWorldEvent(World.tailwallet);
            }
            World.payToHead +=1;
            if(World.payToHead == 2){
                World.payToHead = 0;
                if(World.isWalletHead){
                    worldPayWallets(rootAddres, rootAddres, World.isWallettail);
                    if(wallets[World.headWallet].isWalletNext){
                        World.isWalletHead =true;
                        World.headWallet = wallets[World.headWallet].nextLinkedWallet;
                    }
                    else{
                        World.isWalletHead = false;
                        World.head = wallets[World.headWallet].nextLinked;
                    }
                }
                else{ 
                    worldPayWallets(rootAddres, World.head, World.isWallettail);
                    users[World.head].activeUser = activeIN.LocalMatrix;
                    if(users[World.head].isWalletnextLinked){
                        World.isWalletHead = true;
                        World.headWallet = users[World.head].nextLinkedIdWallet;
                    }
                    else{
                        World.isWalletHead = false;
                        World.head = users[World.head].nextLinked;
                    }
                }
            }
            else{
                if(World.isWalletHead){
                    worldPayWallets(rootAddres, rootAddres, World.isWalletHead);
                }
                else{
                    worldPayWallets(rootAddres, World.head, World.isWalletHead);
                }
            }
        }
        World.isWallettail = true;
        World.tailwallet = _walletId;
    }
    
    function worldPayWallets(address _from, address _to, bool _isWalletPayed) private{
        if(!address(uint160(_to)).send(payToHeadWorld)){
            address(uint160(_to)).transfer(payToHeadWorld);
        }
        if(_isWalletPayed){
            wallets[World.tailwallet].contractMony -= payToHeadWorld;
        }
        else{
            users[_from].contractMony -= payToHeadWorld;
        }
    }
    
    function makeWallet(uint _walletId) internal{
        Wallet storage newWallet = wallets[_walletId];
            newWallet.id = _walletId;
            newWallet.payCount = 0 ;
            newWallet.contractMony = 0;
            newWallet.isWalletNext = false;
    }
    
}