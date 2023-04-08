pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

contract BNPLService {
    address public admin;
    IERC20 public token; // the ERC20 token used for payments
    IERC721 public nft; // the NFT collection used for loans
    uint public interestRate = 8900; // the interest rate (89%)
    uint public maxLoanAmount; // the maximum loan amount
    uint public minNFTPrice; // the minimum NFT price for loans

    struct Loan {
        address borrower;
        uint loanAmount;
        uint remainingAmount;
        uint repaymentAmount;
        uint repaymentPeriod;
        uint dueDate;
        uint lastPaymentDate;
        bool default;
    }

    mapping (uint => Loan) public loans;
    uint public nextLoanId = 1;

    event LoanCreated(uint loanId, address borrower, uint loanAmount, uint dueDate);
    event LoanRepaid(uint loanId, uint repaymentAmount);

    constructor(address _admin, address _token, address _nft, uint _maxLoanAmount, uint _minNFTPrice) {
        admin = _admin;
        token = IERC20(_token);
        nft = IERC721(_nft);
        maxLoanAmount = _maxLoanAmount;
        minNFTPrice = _minNFTPrice;
    }

    function createLoan(uint _nftId, uint _loanAmount, uint _repaymentPeriod) external {
        require(msg.sender != admin, "Admin cannot create loans");
        require(_loanAmount > 0 && _loanAmount <= maxLoanAmount, "Invalid loan amount");
        require(nft.ownerOf(_nftId) == msg.sender, "Sender must own NFT");
        require(nft.getApproved(_nftId) == address(this), "Contract must be approved to transfer NFT");
        require(nft.isApprovedForAll(msg.sender, address(this)), "Contract must be approved to manage NFTs");
        require(nft.price(_nftId) >= minNFTPrice, "NFT price is too low for a loan");

        // Transfer NFT to contract
        nft.safeTransferFrom(msg.sender, address(this), _nftId);

        // Calculate repayment amount and due date
        uint repaymentAmount = _loanAmount * (10000 + interestRate) / 10000;
        uint dueDate = block.timestamp + _repaymentPeriod * 1 days;

        // Create loan and store loan data
        Loan memory newLoan = Loan({
            borrower: msg.sender,
            loanAmount: _loanAmount,
            remainingAmount: _loanAmount,
            repaymentAmount: repaymentAmount,
            repaymentPeriod: _repaymentPeriod,
            dueDate: dueDate,
            lastPaymentDate: 0,
            default: false
        });
        loans[nextLoanId] = newLoan;

        // Emit loan created event
        emit LoanCreated(nextLoanId, msg.sender, _loanAmount, dueDate);

        // Increment loan ID
        nextLoanId++;
    }

   function repayLoan(uint _loanId, uint _repaymentAmount) external {
        require(loans[_loanId].borrower == msg.sender, "Sender must be borrower of loan");
        require(loans[_loanId].default == false, "Loan is in default");

        // Calculate interest
        uint currentTimestamp = block.timestamp;
        uint daysSinceLastPayment = (currentTimestamp - loans[_loanId].lastPaymentDate) / 1 days;
        uint interestAccrued = (daysSinceLastPayment * loans[_loanId].remainingAmount * interestRate) / (10000 * loans[_loanId].repaymentPeriod);
        uint totalRepaymentAmount = loans[_loanId].repaymentAmount + interestAccrued;

        // Transfer tokens from sender to contract
        require(token.transferFrom(msg.sender, address(this), _repaymentAmount), "Transfer failed");

        // Update loan data
        loans[_loanId].remainingAmount -= _repaymentAmount;
        loans[_loanId].lastPaymentDate = currentTimestamp;

        // Check if loan is fully repaid
        if (loans[_loanId].remainingAmount == 0) {
            // Transfer NFT to borrower
            nft.safeTransferFrom(address(this), msg.sender, _nftId);

            // Emit loan repaid event
            emit LoanRepaid(_loanId, totalRepaymentAmount);
        }
    }

    function defaultLoan(uint _loanId) external {
        require(msg.sender == admin, "Sender must be admin");
        require(loans[_loanId].default == false, "Loan is already in default");

        // Transfer NFT to admin
        nft.safeTransferFrom(address(this), admin, _nftId);

        // Set loan as default
        loans[_loanId].default = true;
    }

    function withdrawTokens() external {
        require(msg.sender == admin, "Sender must be admin");

        // Transfer all ERC20 tokens to admin
        token.transfer(msg.sender, token.balanceOf(address(this)));

        // Transfer all ERC721 tokens to admin
        for (uint i = 1; i < nextLoanId; i++) {
            if (nft.ownerOf(i) == address(this)) {
                nft.safeTransferFrom(address(this), admin, i);
            }
        }
    }
}

