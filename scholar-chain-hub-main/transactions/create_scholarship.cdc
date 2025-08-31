import "EduChainScholarship"

transaction(
    name: String,
    description: String,
    amount: UFix64,
    requirements: [String]
) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        let institutionRef = signer.storage.borrow<&EduChainScholarship.Institution>(
            from: EduChainScholarship.InstitutionStoragePath
        ) ?? panic("Could not borrow institution reference")
        
        let scholarshipId = institutionRef.createScholarship(
            name: name,
            description: description,
            amount: amount,
            requirements: requirements
        )
        
        log("Created scholarship with ID: ".concat(scholarshipId.toString()))
    }
}