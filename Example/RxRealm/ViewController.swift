
import UIKit

import RxSwift
import RxCocoa

import RealmSwift
import RxRealm

//realm model
class Lap: Object {
    dynamic var time: TimeInterval = Date().timeIntervalSinceReferenceDate
}

class TickCounter: Object {
    dynamic var id = UUID().uuidString
    dynamic var ticks: Int = 0
    override static func primaryKey() -> String? { return "id" }
}

//view controller
class ViewController: UIViewController {
    let bag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tickItemButton: UIBarButtonItem!
    @IBOutlet weak var addTwoItemsButton: UIBarButtonItem!

    var laps: Results<Lap>!

    let footer: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        return l
    }()

    lazy var ticker: TickCounter = {
        let realm = try! Realm()
        let ticker = TickCounter()
        try! realm.write {
            realm.add(ticker)
        }
        return ticker
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let realm = try! Realm()
        laps = realm.objects(Lap.self).sorted(byKeyPath: "time", ascending: false)

        /*
         Observable<Results<Lap>> - wrap Results as observable
         */
        Observable.collection(from: laps)
            .map {results in "laps: \(results.count)"}
            .subscribe { event in
                self.title = event.element
            }
            .addDisposableTo(bag)

        /*
         Observable<Results<Lap>> - reacting to change sets
         */
        Observable.changeset(from: laps)
            .subscribe(onNext: {[unowned self] results, changes in
                if let changes = changes {
                    self.tableView.applyChangeset(changes)
                } else {
                    self.tableView.reloadData()
                }
            })
            .addDisposableTo(bag)
        
        /*
         Use bindable sink to add objects
         */
        addTwoItemsButton.rx.tap
            .map { [Lap(), Lap()] }
            .bindTo(Realm.rx.add())
            .addDisposableTo(bag)

        /*
         Bind bar item to increasing the ticker
         */
        tickItemButton.rx.tap
            .subscribe(onNext: {[unowned self] value in
                try! realm.write {
                    self.ticker.ticks += 1
                }
            })
            .addDisposableTo(bag)

        /*
         Observing a single object
         */
        let tickerChanges$ = Observable.propertyChanges(object: ticker)
        tickerChanges$
            .filter({ $0.name == "ticks" })
            .map({ "\($0.newValue!) ticks" })
            .bindTo(footer.rx.text)
            .addDisposableTo(bag)
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return laps.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let lap = laps[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = formatter.string(from: Date(timeIntervalSinceReferenceDate: lap.time))
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Delete objects by tapping them, add ticks to trigger a footer update"
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Observable.from([laps[indexPath.row]])
            .subscribe(Realm.rx.delete())
            .addDisposableTo(bag)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return footer
    }
}

extension UITableView {
    func applyChangeset(_ changes: RealmChangeset) {
        beginUpdates()
        deleteRows(at: changes.deleted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        insertRows(at: changes.inserted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        reloadRows(at: changes.updated.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        endUpdates()
    }
}
