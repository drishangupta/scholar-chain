import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

access(all) contract EduChainScholarship {

    // Events
    access(all) event ScholarshipCreated(id: UInt64, amount: UFix64, institution: Address)
    access(all) event ApplicationSubmitted(scholarshipId: UInt64, applicant: Address)
    access(all) event ApplicationApproved(scholarshipId: UInt64, applicant: Address, amount: UFix64)
    access(all) event FundsDistributed(scholarshipId: UInt64, recipient: Address, amount: UFix64)

    // Paths
    access(all) let InstitutionStoragePath: StoragePath
    access(all) let InstitutionPublicPath: PublicPath
    access(all) let StudentStoragePath: StoragePath
    access(all) let StudentPublicPath: PublicPath

    // Total scholarships created
    access(all) var totalScholarships: UInt64

    // Scholarship struct
    access(all) struct Scholarship {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let description: String
        access(all) let amount: UFix64
        access(all) let institution: Address
        access(all) let requirements: [String]
        access(all) var isActive: Bool
        access(all) var applicants: [Address]
        access(all) var approved: [Address]

        init(
            id: UInt64,
            name: String,
            description: String,
            amount: UFix64,
            institution: Address,
            requirements: [String]
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.amount = amount
            self.institution = institution
            self.requirements = requirements
            self.isActive = true
            self.applicants = []
            self.approved = []
        }

        access(contract) fun addApplicant(applicant: Address) {
            if !self.applicants.contains(applicant) {
                self.applicants.append(applicant)
            }
        }

        access(contract) fun approveApplicant(applicant: Address) {
            if self.applicants.contains(applicant) && !self.approved.contains(applicant) {
                self.approved.append(applicant)
            }
        }

        access(contract) fun deactivate() {
            self.isActive = false
        }
    }

    // Public Interfaces
    access(all) resource interface InstitutionPublic {
        access(all) fun receiveApplication(scholarshipId: UInt64, applicant: Address)
        access(all) fun getScholarships(): {UInt64: Scholarship}
    }

    access(all) resource interface StudentPublic {
        access(all) fun getAppliedScholarships(): [UInt64]
        access(all) fun getApprovedScholarships(): [UInt64]
    }

    // Institution Resource
    access(all) resource Institution: InstitutionPublic {
        access(all) let id: UInt64
        access(all) var name: String
        access(all) var scholarships: {UInt64: Scholarship}
        // Use concrete FlowToken.Vault type for storage
        access(all) var vault: @FlowToken.Vault

        init(name: String) {
            self.id = self.uuid
            self.name = name
            self.scholarships = {}
            // createEmptyVault with vaultType parameter for Cadence 1.0
            self.vault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
        }

        access(all) fun createScholarship(
            name: String,
            description: String,
            amount: UFix64,
            requirements: [String]
        ): UInt64 {
            let scholarshipId = EduChainScholarship.totalScholarships
            let instAddr = self.owner?.address ?? panic("Institution must be stored in an account")
            let scholarship = Scholarship(
                id: scholarshipId,
                name: name,
                description: description,
                amount: amount,
                institution: instAddr,
                requirements: requirements
            )

            self.scholarships[scholarshipId] = scholarship
            EduChainScholarship.totalScholarships = EduChainScholarship.totalScholarships + 1

            emit ScholarshipCreated(
                id: scholarshipId,
                amount: amount,
                institution: instAddr
            )

            return scholarshipId
        }

        access(all) fun approveApplication(scholarshipId: UInt64, applicant: Address) {
            pre {
                self.scholarships.containsKey(scholarshipId): "Scholarship does not exist"
            }

            let scholarship = &self.scholarships[scholarshipId] as &Scholarship?
            scholarship!.approveApplicant(applicant: applicant)

            emit ApplicationApproved(
                scholarshipId: scholarshipId,
                applicant: applicant,
                amount: scholarship!.amount
            )
        }

        access(all) fun distributeFunds(scholarshipId: UInt64, recipient: Address) {
            pre {
                self.scholarships.containsKey(scholarshipId): "Scholarship does not exist"
            }

            let scholarship = &self.scholarships[scholarshipId] as &Scholarship?

            if scholarship!.approved.contains(recipient) {
                let recipientRef = getAccount(recipient)
                    .capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    .borrow()
                    ?? panic("Could not borrow recipient's Vault reference")

                // Withdraw from institution's vault (FlowToken.Vault) — returns a FlowToken Vault resource
                let payment <- self.vault.withdraw(amount: scholarship!.amount)

                // deposit expects @FungibleToken.Vault, FlowToken.Vault implements it, so this works
                recipientRef.deposit(from: <-payment)

                emit FundsDistributed(
                    scholarshipId: scholarshipId,
                    recipient: recipient,
                    amount: scholarship!.amount
                )
            }
        }

        // Accept an explicit FlowToken Vault resource
        access(all) fun depositFunds(vault: @FlowToken.Vault) {
            self.vault.deposit(from: <-vault)
        }

        access(all) fun getScholarships(): {UInt64: Scholarship} {
            return self.scholarships
        }

        access(all) fun receiveApplication(scholarshipId: UInt64, applicant: Address) {
            pre {
                self.scholarships.containsKey(scholarshipId): "Scholarship does not exist"
            }

            let scholarship = &self.scholarships[scholarshipId] as &Scholarship?
            scholarship!.addApplicant(applicant: applicant)
        }

    }

    // Student Resource
    access(all) resource Student: StudentPublic {
        access(all) let id: UInt64
        access(all) var name: String
        access(all) var appliedScholarships: [UInt64]
        access(all) var approvedScholarships: [UInt64]

        init(name: String) {
            self.id = self.uuid
            self.name = name
            self.appliedScholarships = []
            self.approvedScholarships = []
        }

        access(all) fun applyForScholarship(scholarshipId: UInt64, institutionAddress: Address) {
            let institutionRef = getAccount(institutionAddress)
                .capabilities.get<&{EduChainScholarship.InstitutionPublic}>(EduChainScholarship.InstitutionPublicPath)
                .borrow()
                ?? panic("Could not borrow institution reference")

            institutionRef.receiveApplication(
                scholarshipId: scholarshipId,
                applicant: self.owner?.address ?? panic("Student must be stored in an account")
            )

            if !self.appliedScholarships.contains(scholarshipId) {
                self.appliedScholarships.append(scholarshipId)
            }

            emit ApplicationSubmitted(
                scholarshipId: scholarshipId,
                applicant: self.owner?.address ?? panic("Student must be stored in an account")
            )
        }

        access(all) fun addApprovedScholarship(scholarshipId: UInt64) {
            if !self.approvedScholarships.contains(scholarshipId) {
                self.approvedScholarships.append(scholarshipId)
            }
        }

        access(all) fun getAppliedScholarships(): [UInt64] {
            return self.appliedScholarships
        }

        access(all) fun getApprovedScholarships(): [UInt64] {
            return self.approvedScholarships
        }
    }

    // Public functions
    access(all) fun createInstitution(name: String): @Institution {
        return <-create Institution(name: name)
    }

    access(all) fun createStudent(name: String): @Student {
        return <-create Student(name: name)
    }

    access(all) fun getAllScholarships(): {Address: {UInt64: Scholarship}} {
        let scholarships: {Address: {UInt64: Scholarship}} = {}
        // This would require a registry of all institutions
        // For now, return empty - in practice, you'd maintain a registry
        return scholarships
    }

    init() {
        self.totalScholarships = 0

        self.InstitutionStoragePath = /storage/EduChainInstitution
        self.InstitutionPublicPath = /public/EduChainInstitution
        self.StudentStoragePath = /storage/EduChainStudent
        self.StudentPublicPath = /public/EduChainStudent
    }
}
