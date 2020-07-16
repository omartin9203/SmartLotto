// SPDX-License-Identifier: MIT
pragma solidity >=0.4.26 <0.7.0;


contract SmartLotto {
    
    event SignUpEvent(address indexed _newUser, uint indexed _userId, address indexed _sponsor, uint _sponsorId);
    event NewUserChildEvent(address indexed _user, address indexed _sponsor, uint8 _box, bool _isSmartDirect, uint8 _position);
    event ReinvestBoxEvent(address indexed _user, address indexed currentSponsor, address indexed addrCaller, uint8 _box, bool _isSmartDirect);
    event MissedEvent(address indexed _from, address indexed _to, uint8 _box, bool _isSmartDirect);
    event SentExtraEvent(address indexed _from, address indexed _to, uint8 _box, bool _isSmartDirect);
    event UpgradeStatusEvent(address indexed _user, address indexed _sponsor, uint8 _box, bool _isSmartDirect);
    
    enum NodeChieldType {
        Inactive,
        InvitedByYou,
        BottomOverflow,
        UpOverflow,
        SurpassedSponsor
    }

    struct SmartDirectBox {
        bool purchased;
        bool inactive;
        uint reinvests;
        address[] childs;
        address currentSponsor;
    }

    struct SmartTeamBox {
        bool purchased;
        bool inactive;
        uint reinvests;
        address[] childs;
        address currentSponsor;
    }

    struct User {
        uint id;
        uint partnersCount;
        mapping(uint8=>SmartDirectBox) directBoxes;
        mapping(uint8=>SmartTeamBox) teamBoxes;
        address sponsor;
    }

    uint nextId = 1;
    address payable externalAddress;
    address payable lotteryAddress;
    mapping(address=>User) public users;
    mapping(uint=>address payable) public idLookup;
    
    uint[14] boxesValues = [0.02 ether, 0.04 ether, 0.08 ether, 0.16 ether, 0.32 ether, 0.64 ether,
     1.28 ether, 2.56 ether, 5.12 ether, 10.24 ether, 20.48 ether, 40.96 ether, 81.9 ether, 163.8 ether];
    
    uint[14] boxes30PtgValues = [0.006 ether, 0.012 ether, 0.024 ether, 0.048 ether, 0.096 ether, 0.192 ether,
     0.384 ether, 0.768 ether, 1.536 ether, 3.72 ether, 6.14 ether, 12.28 ether, 24.57 ether, 49.15 ether];

    uint[14] boxesLotteryValues = [0.0045 ether, 0.009 ether, 0.018 ether, 0.036 ether, 0.072 ether, 0.144 ether,
     0.288 ether, 0.576 ether, 1.152 ether, 2.304 ether, 4.608 ether, 9.216 ether, 18.432 ether, 36.855 ether];

    uint[14] boxesExternalValues = [0.0015 ether, 0.003 ether, 0.006 ether, 0.012 ether, 0.024 ether, 0.048 ether,
     0.096 ether, 0.192 ether, 0.384 ether, 0.768 ether, 1.536 ether, 3.072 ether, 6.142 ether, 12.288 ether];

    modifier validSponsor(address _sponsor) {
        require(users[_sponsor].id != 0, "This sponsor does not exists");
        _;
    }

    modifier onlyUser() {
        require(users[msg.sender].id != 0, "This user does not exists");
        _;
    }
    
    modifier validNewUser(address _newUser) {
        uint32 size;
        assembly { size := extcodesize(_newUser) }
        require(size == 0, "The new user cannot be a contract");
        require(users[_newUser].id == 0, "This user already exists");
        _;
    }

    modifier validBox(uint _box) {
        require(_box >= 1 && _box <= 14, "Invalid box");
        _;
    }

    constructor(address payable _externalAddress, address payable _lotteryAddress) public {
        externalAddress = _externalAddress;
        lotteryAddress = _lotteryAddress;

        User storage root = users[_externalAddress];
        root.id = nextId++;
        idLookup[root.id] = _externalAddress;
        for (uint8 i = 1; i <= 14; i++) {
            root.directBoxes[i].purchased = true;
            root.teamBoxes[i].purchased = true;
        }
    }

    receive() external payable {
        if(msg.data.length == 0) return signUp(msg.sender, externalAddress);
        address sponsor;
        bytes memory data = msg.data;
        assembly {
            sponsor := mload(add(data, 20))
        }
        signUp(msg.sender, sponsor);
    }

    function signUp(address payable _newUser, address _sponsor) private validSponsor(_sponsor) validNewUser(_newUser) {
        require(msg.value == 0.04 ether, "Please enter required amount (0.04 ether)");

        // user node data
        User storage userNode = users[_newUser];
        userNode.id = nextId++;
        userNode.sponsor = _sponsor;
        userNode.directBoxes[1].purchased = true;
        userNode.teamBoxes[1].purchased = true;
        idLookup[userNode.id] = _newUser;
        
        users[_sponsor].partnersCount++;
        
        
        userNode.directBoxes[1].currentSponsor = _sponsor;
        modifySmartDirectSponsor(_sponsor, _newUser, 1);
        
        // todo: Modify SmartTeamSponsor
        
        emit SignUpEvent(_newUser, userNode.id, _sponsor,  users[_sponsor].id);
    }

    function signUp(address sponsor) external payable {
        signUp(msg.sender, sponsor);
    }
    
    function buyNewBox(uint8 _matrix, uint8 _box) external payable onlyUser validBox(_box) {
        require(_matrix == 1 || _matrix == 2, "Invalid matrix");
        require(msg.value == boxesValues[_box - 1], "Please enter required amount");
        User storage userData = users[msg.sender];
        if (_matrix == 1) {
            require(!userData.directBoxes[_box].purchased, "You already bought that box");
            require(userData.directBoxes[_box - 1].purchased, "Please bought the boxes prior to this");
            
            userData.directBoxes[_box].purchased = true;
            userData.directBoxes[_box - 1].inactive = false;
            address sponsorResult = findSmartDirectSponsor(msg.sender, _box);
            userData.directBoxes[_box].currentSponsor = sponsorResult;
            modifySmartDirectSponsor(sponsorResult, msg.sender, _box);
            emit UpgradeStatusEvent(msg.sender, sponsorResult, _box, true);
        } else {
            require(!userData.teamBoxes[_box].purchased, "level already activatedYou already bought that box"); 
            require(userData.teamBoxes[_box - 1].purchased, "Please bought the boxes prior to this");
            //todo: Implementation for SmartTeam
        }
    }
    
    function findSmartDirectSponsor(address _addr, uint8 _box) internal view returns(address) {
        User memory node = users[_addr];
        if (users[node.sponsor].directBoxes[_box].purchased) return node.sponsor;
        return findSmartDirectSponsor(node.sponsor, _box);
    }

    function modifySmartDirectSponsor(address _sponsor, address _user, uint8 _box) private {
        users[_sponsor].directBoxes[_box].childs.push(_user);
        uint8 position = uint8(users[_sponsor].directBoxes[_box].childs.length);
        emit NewUserChildEvent(_user, _sponsor, _box, true, position);
        if (position < 3)
            return applyDistribution(_user, _sponsor, _box, true);
        SmartDirectBox storage directData = users[_sponsor].directBoxes[_box];
        directData.childs = new address[](0);
        if (!users[_sponsor].directBoxes[_box + 1].purchased && _box != 14) directData.inactive = true;
        directData.reinvests++;
        if (externalAddress != _sponsor) {
            address sponsorResult = findSmartDirectSponsor(_sponsor, _box);
            directData.currentSponsor = sponsorResult;
            emit ReinvestBoxEvent(_sponsor, sponsorResult, _user, _box, true);
            modifySmartDirectSponsor(sponsorResult, _sponsor, _box);
        } else {
            applyDistribution(_user, _sponsor, _box, true);
            emit ReinvestBoxEvent(_sponsor, address(0), _user, _box, true);
        }
    }

    function applyDistribution(address _from, address _to, uint8 _box, bool _isSmartDirect) private {
        (address receiver, bool haveMissed) = getReciver(_from, _to, _box, _isSmartDirect, false);
        uint p70 = boxesValues[_box - 1] - boxes30PtgValues[_box - 1];
        address(uint160(receiver)).transfer(p70);
        externalAddress.transfer(boxesExternalValues[_box - 1]);
        lotteryAddress.transfer(address(this).balance);
        if (haveMissed) emit SentExtraEvent(_from, receiver, _box, _isSmartDirect);
    }
    
    function getReciver(address _from, address _to, uint8 _box, bool _isSmartDirect, bool _haveMissed) private  returns(address, bool) {
        bool blocked;
        address sponsor;
        if (_isSmartDirect) {
            SmartDirectBox memory directBoxData = users[_to].directBoxes[_box];
            blocked = directBoxData.inactive;
            sponsor = directBoxData.currentSponsor;
        } else {
            SmartTeamBox memory teamBoxData = users[_to].teamBoxes[_box];
            blocked = teamBoxData.inactive;
            sponsor = teamBoxData.currentSponsor;
        }
        if (!blocked) return (_to, _haveMissed);
        emit MissedEvent(_from, _to, _box, _isSmartDirect);
        return getReciver(_from, sponsor, _box, _isSmartDirect, true);
    }
}