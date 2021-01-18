import Foundation

protocol JetpackBackupStatusView {
    func render(_ backup: JetpackBackup)
    func showError()
    func showComplete()
}

class JetpackBackupStatusCoordinator {

    private let service: JetpackBackupService
    private let site: JetpackSiteRef
    private let view: JetpackBackupStatusView

    init(site: JetpackSiteRef,
         view: JetpackBackupStatusView,
         service: JetpackBackupService? = nil,
         context: NSManagedObjectContext = ContextManager.sharedInstance().mainContext) {
        self.service = service ?? JetpackBackupService(managedObjectContext: context)
        self.site = site
        self.view = view
    }

    func start() {
        service.prepareBackup(for: site, success: { [weak self] backup in
            self?.view.render(backup)
            self?.pollBackupStatus(for: backup.downloadID)
        }, failure: { [weak self] error in
            DDLogError("Error preparing downloadable backup object: \(error.localizedDescription)")

            self?.view.showError()
        })
    }

    private func pollBackupStatus(for downloadID: Int) {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.service.getBackupStatus(for: self.site, downloadID: downloadID, success: { backup in

                // If a backup url exists, then we've finished creating a downloadable backup.
                if backup.url != nil {
                    timer.invalidate()
                    self.view.showComplete()
                    return
                }

                self.view.render(backup)

            }, failure: { [weak self] error in
                DDLogError("Error fetching backup object: \(error.localizedDescription)")

                timer.invalidate()
                self?.view.showError()
            })
        }
    }

}
