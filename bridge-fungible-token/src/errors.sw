library errors;

pub enum BridgeFungibleTokenError {
    UnauthorizedUser: (),
    IncorrectAssetDeposited: (),
    NoCoinsForwarded: (),
}
