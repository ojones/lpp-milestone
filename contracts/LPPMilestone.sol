pragma solidity ^0.4.13;

import "../node_modules/liquidpledging/contracts/LiquidPledging.sol";

contract LPPMilestone {
    uint constant FROM_OWNER = 0;
    uint constant FROM_PROPOSEDPROJECT = 255;
    uint constant TO_OWNER = 256;
    uint constant TO_PROPOSEDPROJECT = 511;

    LiquidPledging public liquidPledging;
    uint public idProject;
    uint public maxAmount;
    address public reviewer;
    address public recipient;
    address public newReviewer;
    address public newRecipient;
    bool public accepted;
    bool public canceled;

    uint public cumulatedReceived;

    function LPPMilestone(LiquidPledging _liquidPledging, string name, uint parentProject, address _recipient, uint _maxAmount, address _reviewer) {
        liquidPledging = _liquidPledging;
        idProject = liquidPledging.addProject(name, address(this), 0, address(this));
        maxAmount = _maxAmount;
        recipient = _recipient;
        reviewer = _reviewer;
    }

    modifier onlyRecipient() {
        require(msg.sender == recipient);
        _;
    }

    modifier onlyReviewer() {
        require(msg.sender == reviewer);
        _;
    }

    function changeRecipient(address _newRecipient) onlyRecipient {
        newRecipient = _newRecipient;
    }

    function changeReviewer(address _newReviewer) onlyReviewer {
        newReviewer = _newReviewer;
    }

    function acceptNewRecipient() {
        require(newRecipient == msg.sender);
        recipient = newRecipient;
        newRecipient = 0;
    }

    function acceptNewReviewer() {
        require(newReviewer == msg.sender);
        reviewer = newReviewer;
        newReviewer = 0;
    }

    function beforeTransfer(uint64 noteManager, uint64 noteFrom, uint64 noteTo, uint64 context, uint amount) returns (uint maxAllowed) {
        require(msg.sender == address(liquidPledging));
        var (, , , fromProposedProject , , , ) = liquidPledging.getNote(noteFrom);
        // If it is proposed or comes from somewhere else of a proposed project, do not allow.
        // only allow from the proposed project to the project in order normalize it.
        if (   (context == TO_PROPOSEDPROJECT)
            || (   (context == TO_OWNER)
                && (fromProposedProject != projectId)))
        {
            if (accepted || canceled) return 0;
        }
        return amount;
    }

    function afterTransfer(uint64 noteManager, uint64 noteFrom, uint64 noteTo, uint64 context, uint _amount) {
        uint returnFunds;
        require(msg.sender == address(liquidPledging));

        var (, oldOwner, , , , , ) = liquidPledging.getNote(noteFrom);
        var (, , , , , oldNote, ) = liquidPledging.getNote(noteTo);

        if ((context == TO_OWNER)&&(oldOwner != projectId)) {  // Recipient of the funds from a different owner

            cumulatedReceived += amount;
            if (accepted || canceled) {
                returnFunds = amount;
            } else if (cumulatedReceived > maxAmount) {
                returnFunds = cumulatedReceived - maxAmount;
            } else {
                returnFunds = 0;
            }

            if (returnFunds > 0) {  // Sends exceding money back
                cumulatedReceived -= returnFunds;
                liquidPledging.cancelNote(idProject, noteTo, returnFunds);
            }
        }
    }

    function acceptMilestone() onlyReviewer {
        require(!canceled);
        require(!accepted);
        accepted = true;
    }

    function cancelMilestone() onlyReviewer {
        require(!canceled);
        require(!accepted);

        liquidPledging.cancelProject(idProject);

        canceled = true;
    }

    function withdraw(uint64 idNote, uint amount) onlyRecipient {
        require(!canceled);
        require(accepted);
        liquidpledging.withdraw(idNote, amount);
        collect();
    }

    function mWithdraw(uint[] notesAmounts) onlyRecipient {
        require(!canceled);
        require(accepted);
        liquidPledging.mWithdraw(notesAmounts);
        collect();
    }

    function collect() onlyRecipient {
        if (this.balance>0) recipient.transfer(this.balance);
    }
}