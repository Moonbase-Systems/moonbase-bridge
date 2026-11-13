//! Contract between MoonBase Studio and MoonBase Bridge.
//!
//! This crate holds the commands, state events, and session identifiers that
//! travel over the localhost transport. It does not depend on the operating
//! system, the renderer, or the transport, so Studio-facing logic can be tested
//! on every platform.
//!
//! The command set and the session lifecycle are defined in STU-23. Until then
//! this crate only exposes the contract version.

/// Version of the Studio ↔ Bridge contract.
///
/// Studio and Bridge exchange it when a session starts. A major version change
/// means the two sides cannot talk to each other.
pub const CONTRACT_VERSION: Version = Version { major: 0, minor: 1 };

/// Contract version made of a major and a minor number.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Version {
    /// Incremented on breaking changes.
    pub major: u16,
    /// Incremented on backwards-compatible additions.
    pub minor: u16,
}

impl Version {
    /// Returns whether a peer speaking `other` can talk to this side.
    pub const fn is_compatible_with(self, other: Self) -> bool {
        self.major == other.major
    }
}

impl std::fmt::Display for Version {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}.{}", self.major, self.minor)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_major_is_compatible() {
        let peer = Version {
            major: CONTRACT_VERSION.major,
            minor: CONTRACT_VERSION.minor + 1,
        };
        assert!(CONTRACT_VERSION.is_compatible_with(peer));
    }

    #[test]
    fn different_major_is_not_compatible() {
        let peer = Version {
            major: CONTRACT_VERSION.major + 1,
            minor: 0,
        };
        assert!(!CONTRACT_VERSION.is_compatible_with(peer));
    }

    #[test]
    fn displays_as_major_dot_minor() {
        assert_eq!(Version { major: 2, minor: 7 }.to_string(), "2.7");
    }
}
