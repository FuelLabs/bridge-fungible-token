library errors;

pub enum Error {
    CannotReinitialize: (),
    StateNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
}
