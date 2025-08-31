import "EduChainScholarship"

transaction(scholarshipId: UInt64, institutionAddress: Address) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        let studentRef = signer.storage.borrow<&EduChainScholarship.Student>(
            from: EduChainScholarship.StudentStoragePath
        ) ?? panic("Could not borrow student reference")
        
        studentRef.applyForScholarship(
            scholarshipId: scholarshipId,
            institutionAddress: institutionAddress
        )
        
        log("Applied for scholarship ID: ".concat(scholarshipId.toString()))
    }
}