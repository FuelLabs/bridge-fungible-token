library errors;

pub enum BridgeFungibleTokenError {
    CannotReinitialize: (),
    ContractNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
    NoCoinsForwarded: (),
    IncorrectMessageOwner: (),
}
