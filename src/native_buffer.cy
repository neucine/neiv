// Views of native memory valid only for the duration of a synchronous callback.
// The native caller retains ownership. Do not store these pointers after return.
pub struct ReadBuffer {
    pub pointer: *const u8;
    pub length: usize;
}

pub struct WriteBuffer {
    pub pointer: *u8;
    pub length: usize;
}
