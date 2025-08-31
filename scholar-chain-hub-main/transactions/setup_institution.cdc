import "EduChainScholarship"

transaction(name: String) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Check if institution already exists
        if signer.storage.borrow<&EduChainScholarship.Institution>(from: EduChainScholarship.InstitutionStoragePath) != nil {
            panic("Institution already exists")
        }
        
        // Create new institution
        let institution <- EduChainScholarship.createInstitution(name: name)
        
        // Store institution in account storage
        signer.storage.save(<-institution, to: EduChainScholarship.InstitutionStoragePath)
        
        // Create public capability
        let cap = signer.capabilities.storage.issue<&{EduChainScholarship.InstitutionPublic}>(EduChainScholarship.InstitutionStoragePath)
        signer.capabilities.publish(cap, at: EduChainScholarship.InstitutionPublicPath)
    }
}