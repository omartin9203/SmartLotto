pragma solidity >=0.4.26 <0.7.0;


contract SmartLotto {
    
    event RegistrationEvent(address indexed newUser, uint indexed userId, address indexed sponsor, uint sponsorId);

    
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
        NodeChieldType[3] childs;
        address currentSponsor;
    }

    struct SmartTeamBox {
        bool purchased;
        bool inactive;
        uint reinvests;
        NodeChieldType[6] childs;
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

    function signUp(address payable newUser, address sponsor) private {
        require(users[sponsor].id != 0, "This sponsor does not exists");
        require(users[newUser].id == 0, "This user already exists");
        uint32 size;
        assembly { size := extcodesize(newUser) }
        require(size == 0, "The new user cannot be a contract");
        require(msg.value == 0.04 ether, "Please enter required amount (0.04 ether)");

        // user node data
        User storage userNode = users[newUser];
        userNode.id = nextId++;
        userNode.sponsor = sponsor;
        userNode.directBoxes[1].purchased = true;
        userNode.teamBoxes[1].purchased = true;
        idLookup[userNode.id] = newUser;
        
        users[sponsor].partnersCount++;
        
        // todo
        userNode.directBoxes[1].currentSponsor = sponsor;

        emit RegistrationEvent(newUser, userNode.id, sponsor,  users[sponsor].id);
    }

    
    function signUp(address sponsor) external payable {
        signUp(msg.sender, sponsor);
    }
    
    function findDirectSponsor(address addr, uint8 box) internal view returns(address) {
        User memory node = users[addr];
        if (users[node.sponsor].directBoxes[box].purchased) return node.sponsor;
        return findDirectSponsor(node.sponsor, box);
    }
}