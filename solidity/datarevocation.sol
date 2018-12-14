pragma solidity 0.4.24;

contract DataRevocation {
    
address datafeed; address provider;
event CheckAccessEvent(
       address indexed _from, uint256 _value);
int tThreshold; 
uint compensation;

struct Item {
 address owner; int256 expiry; uint256 state;
}

mapping(uint256 => Item) public items; 
uint256 public itemCount; 
uint256 minCoverPct; uint256 minCoverAbs;

/* Constructor */
/* Adresses of provider and data feed are fixed according 
to the test setup on our local private blockchain */ 
constructor() public {
 datafeed 
  = 0x3C58da5683c9Ad75Db504F4Cbb4728ae0732978C;
 provider 
  = 0x18A3CFa5064EcF30A31e249caC5596740899045b;
 itemCount = 0; minCoverPct = 1; minCoverAbs = 1;
 tThreshold = 10 * 1 minutes; compensation = 0.05 ether;
}

/* Data owners can register their items in the contract */
function addItem(uint256 id, uint256 tLeft) public {
    handleAdd(id, tLeft, msg.sender);
}

function handleAdd(uint256 id, uint256 tLeft, 
          address addrU) private {
    if(items[id].state < 1) {
        initItem(id, tLeft, addrU);
        items[id].state = 1;
    } else if(items[id].state == 2 
        && equalConditions(id, tLeft, addrU)) {
        items[id].state = 3;
    } else {
        revert();
    }
}

/* Providers can confirm data items in the contract */
function confirmItem(uint256 id, uint256 tLeft, 
          address addrU) public payable {
    uint bal = address(this).balance;
    if(msg.sender == provider) {
        if(bal > minThreshold()) {
             itemCount++;
             handleConfirm(id, tLeft, addrU);
        } else {
             revert();
        }
    } else {
        if(!msg.sender.send(msg.value)) {
            revert();
        }
    }
}

function handleConfirm(uint256 id, uint256 tLeft, 
          address addrU) private {
    if(items[id].state < 1) {
        initItem(id, tLeft, addrU);
        items[id].state = 2;
    } else if(items[id].state < 2 
       && equalConditions(id, tLeft, addrU)) {
        items[id].state = 3;
    } else {
        revert();
    }
}

/* Provider confirmation is only successful if the 
contract balance is higher than the threshold */
function minThreshold() view private returns (uint) {
    uint pct = itemCount * minCoverPct 
         * compensation/100;
    uint abs = minCoverAbs 
         * compensation;
    uint threshold;

    if(pct < abs) {
        threshold = pct;
    } else {
        threshold = abs;
    }

    return threshold;
}

/* Registration is only successful if conditions 
specified by owner and provider are equal */
function equalConditions(uint256 id, uint256 tLeft, 
          address addrU) view private returns (bool)  {
    int expChal = (int)(now + tLeft * 1 minutes);
    if((items[id].expiry - expChal <= tThreshold) 
        && (expChal - items[id].expiry <= tThreshold) 
            && items[id].owner == addrU) {
        return true;
    }
    return false;
}

/* Finalizing the registration after both owner and
provider have committed to the contract */
function initItem(uint256 id, uint256 tLeft, 
          address addrU) private {
    items[id].expiry = int(now + (tLeft * 1 minutes));
    items[id].owner = addrU;
}

/* Data owner may remove data items from the contract */
function removeItem(uint256 id) public {
    if(items[id].owner == msg.sender 
     && items[id].state > 0) {
        if(items[id].state > 1) {
            itemCount--;
        }
        
        delete items[id];
    }
}

/* Provider may remove items from the contract
as long as the owner has not registered it */
function removeUncreatedItemAsProvider(uint256 id) public {
    if(msg.sender == provider 
     && items[id].state == 2) {
        delete items[id];
        itemCount--;
    }
}

/* Check if the expiration condition is fulfilled */
function checkExpiry(uint256 id) public {
    if(items[id].state == 3 
       && (int(now) > items[id].expiry)) {
        items[id].state = 4;
    }
}

/* Check contract violation */
function verifyAccess(uint256 id) public {
    if(items[id].state < 4) {
        checkExpiry(id);
    }
    
    if(items[id].state == 4) {
        items[id].state = 5;
        emit CheckAccessEvent(msg.sender, id);
    }
}

/* Data Feed can report successful access which
leads to the compensation process */
function itemFound(uint256 id) public {
    if(msg.sender == datafeed 
     && items[id].state == 5) {
        items[id].state = 6;
        
        if(!items[id].owner.send(
         compensation)) {
            items[id].state = 7;
        } 
    }
}

/* Owner can manually claim a compensation after a contract
violation has been reported and not yet been compensated */
function claimPending(uint256 id) public {
    if(items[id].state==7) {
        if(!items[id].owner.send(
         compensation)) {
            revert();
        } else {
            items[id].state = 8;
        }
    }
}

/* Provider can reduce the contracts balance as long as
the total amount remains above the reserve threshold */
function providerWithdrawal() public {
    if(msg.sender == provider) {
        uint bal = address(this).balance;
        uint refund = 0;

        if(bal > minThreshold()) {
            refund = bal - minThreshold();
        }
        
        if(!provider.send(refund)) {
            revert();
        }
    }
}
}