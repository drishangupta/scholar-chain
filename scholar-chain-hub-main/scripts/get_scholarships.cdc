import "EduChainScholarship"

access(all) fun main(institutionAddress: Address): {UInt64: EduChainScholarship.Scholarship} {
    let institutionRef = getAccount(institutionAddress)
        .capabilities.get<&{EduChainScholarship.InstitutionPublic}>(EduChainScholarship.InstitutionPublicPath)
        .borrow()
        ?? panic("Could not borrow institution reference")
    
    return institutionRef.getScholarships()
}