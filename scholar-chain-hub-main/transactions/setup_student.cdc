import "EduChainScholarship"

transaction(name: String) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Check if student already exists
        if signer.storage.borrow<&EduChainScholarship.Student>(from: EduChainScholarship.StudentStoragePath) != nil {
            panic("Student already exists")
        }
        
        // Create new student
        let student <- EduChainScholarship.createStudent(name: name)
        
        // Store student in account storage
        signer.storage.save(<-student, to: EduChainScholarship.StudentStoragePath)
        
        // Create public capability
        let cap = signer.capabilities.storage.issue<&{EduChainScholarship.StudentPublic}>(EduChainScholarship.StudentStoragePath)
        signer.capabilities.publish(cap, at: EduChainScholarship.StudentPublicPath)
    }
}