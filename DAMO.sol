//SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface ERC721 {
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    function balanceOf(address _owner) external view returns (uint256);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) external payable;

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    function approve(address _approved, uint256 _tokenId) external payable;

    function setApprovalForAll(address _operator, bool _approved) external;

    function getApproved(uint256 _tokenId) external view returns (address);

    function isApprovedForAll(address _owner, address _operator)
        external
        view
        returns (bool);
}

interface ERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

interface ERC721Metadata {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface ERC721Enumerable {
    function totalSupply() external view returns (uint256);

    function tokenByIndex(uint256 _index) external view returns (uint256);

    function tokenOfOwnerByIndex(address _owner, uint256 _index)
        external
        view
        returns (uint256);
}

interface ERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

contract DAMO is ERC721, ERC165, ERC721Metadata, ERC721Enumerable {
    //Metadata
    string private _tokenName;
    string private _tokenSymbol;
    uint16 private id = 1;
    address public contract_owner;

    //enumeration
    uint256[] private allTokens;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;

    constructor(string memory _name, string memory _symbol) {
        _tokenName = _name;
        _tokenSymbol = _symbol;
        contract_owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == contract_owner);
        _;
    }

    function name() external view virtual override returns (string memory) {
        return _tokenName;
    }

    function symbol() external view virtual override returns (string memory) {
        return _tokenSymbol;
    }

    //EIP-721 Standard

    mapping(address => uint16) private _balance;
    mapping(uint256 => address) private _owners;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    //token to price
    mapping(uint256 => uint256) public tokenToPrice;

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "Token does not exist!!");
        return _tokenURIs[_tokenId];
    }

    function balanceOf(address _owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(_owner != address(0), "Invalid Query");
        return _balance[_owner];
    }

    function ownerOf(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        address owner = _owners[_tokenId];
        require(owner != address(0), "Invalid NFT/Token");
        return owner;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public payable virtual override {
        require(msg.sender != _to, "Invalid Reciever Address");
        require(_to != address(0), "Invalid Reciever Address");
        require(_from == msg.sender, "Not the current owner");
        require(_exists(_tokenId), "Invalid NFT/Token");
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual {
        require(_exists(_tokenId), "NFT does not exist");
        require(_from == msg.sender, "Not the current owner");
        require(msg.sender != _to, "Invalid Reciever Address");
        require(
            msg.value >= tokenToPrice[_tokenId],
            "Pay the right price for token"
        );
        _beforeTokenTransfers(_to, _from, _tokenId);
        _balance[_from] -= 1;
        _balance[_to] += 1;
        _owners[_tokenId] = _to;
        tokenToPrice[_tokenId] = msg.value;
        emit Transfer(_from, _to, _tokenId);
    }

    function changePrice(uint256 price, uint256 tokenId) public virtual {
        require(_exists(tokenId), "Token does not exists");
        require(msg.sender == _owners[tokenId], "You are not the owner");
        tokenToPrice[tokenId] = price;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _setTokenURI(uint256 tokenId, string memory uri) internal virtual {
        require(_exists(tokenId), "Token does not exist");
        _tokenURIs[tokenId] = uri;
    }

    function mintToken(
        address to,
        string memory uri,
        uint256 price
    ) public payable {
        tokenToPrice[id] = price;
        mint(to, uri);
    }

    function mint(address to, string memory uri) public payable {
        // require(_balance[to] < 5, "Max Quantity Reached");
        uint256 tokenId = id;
        _beforeTokenTransfers(to, address(0), tokenId);
        _owners[tokenId] = to;
        _balance[to] += 1;
        id++;
        _setTokenURI(tokenId, uri);
        emit Transfer(address(0), to, tokenId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) public payable virtual override {
        require(msg.sender != _to, "Invalid Reciever Address");
        require(_to != address(0), "Invalid Reciever Address");
        require(_from == msg.sender, "Not the current owner");
        require(_exists(_tokenId), "Invalid NFT/Token");
        _safeTransfer(_from, _to, _tokenId, data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public payable virtual override {
        require(_exists(_tokenId), "Token does not exist!!");
        require(_owners[_tokenId] != msg.sender, "You are not the owner");
        require(_to != address(0), "Invalid address");

        _transfer(_from, _to, _tokenId);
    }

    function _transferNFT(
        address _from,
        address _to,
        uint256 tokenId,
        uint256 price
    ) public payable {}

    function approve(address _approved, uint256 _tokenId)
        public
        payable
        virtual
        override
    {
        require(_approved != _owners[_tokenId], "Approval to current owner.");
        require(
            msg.sender == _owners[_tokenId] ||
                isApprovedForAll(_owners[_tokenId], msg.sender)
        );
        _approve(_approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved)
        public
        virtual
        override
    {
        _setApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        require(
            _exists(_tokenId),
            "ERC721: approved query for nonexistent token"
        );
        return _tokenApprovals[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[_owner][_operator];
    }

    function _approve(address _approved, uint256 _tokenId) internal virtual {
        _tokenApprovals[_tokenId] = _approved;
        emit Approval(_owners[_tokenId], _approved, _tokenId);
    }

    function _setApprovalForAll(
        address _owner,
        address _operator,
        bool _approved
    ) internal virtual {
        require(_owner != _operator, "ERC721: approve to caller");
        _operatorApprovals[_owner][_operator] = _approved;
        emit ApprovalForAll(_owner, _operator, _approved);
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (isContract(to)) {
            try
                ERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == ERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    //EIP-165

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165)
        returns (bool)
    {
        return
            interfaceId == type(ERC721).interfaceId ||
            interfaceId == type(ERC721Metadata).interfaceId ||
            interfaceId == type(ERC165).interfaceId ||
            interfaceId == type(ERC721Enumerable).interfaceId;
    }

    function selfDestroy(address payable _rec) public onlyOwner {
        selfdestruct(_rec);
    }

    //ERC721 Enumerable

    function totalSupply() external view virtual override returns (uint256) {
        return totalTokenSupply();
    }

    function totalTokenSupply() internal view returns (uint256) {
        return allTokens.length;
    }

    function tokenByIndex(uint256 _index)
        external
        view
        virtual
        override
        returns (uint256)
    {
        require(_index <= totalTokenSupply(), "Invalid Index");
        return allTokens[_index - 1];
    }

    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        virtual
        override
        returns (uint256)
    {
        require(owner != address(0), "Invalid Owner");
        require(
            index < balanceOf(owner),
            "ERC721Enumerable: owner index out of bounds"
        );
        return _ownedTokens[owner][index];
    }

    function _beforeTokenTransfers(
        address _to,
        address _from,
        uint256 _tokenId
    ) internal virtual {
        if (_from == address(0)) {
            allTokens.push(_tokenId);
            uint256 length = balanceOf(_to);
            _ownedTokens[_to][length] = _tokenId;
            _ownedTokensIndex[_tokenId] = length;
        } else if (_from != _to) {
            require(balanceOf(_from) > 0, "No tokens owned");
            uint256 lastTokenIndex = balanceOf(_from) - 1;
            uint256 tokenIndex = _ownedTokensIndex[_tokenId];
            if (tokenIndex != lastTokenIndex) {
                uint256 lastTokenId = _ownedTokens[_from][lastTokenIndex];

                _ownedTokens[_from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
                _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
            }

            // This also deletes the contents at the last position of the array
            delete _ownedTokensIndex[_tokenId];
            delete _ownedTokens[_from][lastTokenIndex];
        }
        if (_to != _from) {
            uint256 length = balanceOf(_to);
            _ownedTokens[_to][length] = _tokenId;
            _ownedTokensIndex[_tokenId] = length;
        }
    }

    receive() external payable {}
}
