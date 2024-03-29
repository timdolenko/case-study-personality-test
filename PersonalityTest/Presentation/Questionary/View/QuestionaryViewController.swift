import UIKit

class QuestionaryViewController: UIViewController {
    
    weak var titleLbl: UILabel!
    weak var topBar: UIView!
    weak var nextButton: UIButton!
    weak var tableView: UITableView!
    
    weak var popup: PopupView?
    
    weak var coordinator: QuestionaryCoordinator?
    private var viewModel: QuestionaryViewModel!
    private var observationToken: ObservationToken?
    private var state: QuestionaryViewModel.State {
        viewModel.state.value
    }
    
    private enum Section: Int, CaseIterable {
        case question
        case answer
    }
    
    required convenience init(viewModel: QuestionaryViewModel) {
        self.init(nibName: nil, bundle: nil)
        self.viewModel = viewModel
    }
    
    deinit {
        observationToken?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        
        observationToken = viewModel.state.observe { [weak self] (state) in
            self?.viewModelStateDidChange(state)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.send(.didRequestQuestions)
    }
    
    private func viewModelStateDidChange(_ state: QuestionaryViewModel.State) {
        switch state {
        case .initial:
            break
        case .loadingQuestions:
            
            showPopup("Let’s wait for the questions")
        case let .didFailToLoadQuestions(error):
            
            showPopup(with: error)
        case .didDisplay(_):
            hidePopupIfNeeded()
            
            updateNextButtonState()
            tableView.reloadSections(IndexSet(arrayLiteral: 0,1), with: .left)
            
        case .didSelectAnswer(_, _):
            
            updateNextButtonState()
            tableView.reloadSections(IndexSet(integer: Section.answer.rawValue), with: .none)
        
        case .savingResults:
            showPopup("Saving results")
        case let .didFailToSaveResults(error):
            
            showPopup(with: error)
        case .didSaveResults:
            showPopup("We’ve saved your result", icon: #imageLiteral(resourceName: "checkbox_checked.pdf"))
        }
        
        updateTitleIfNeeded(state.title)
    }
    
    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        
        tableView.register(QuestionTextCell.self)
        tableView.register(AnswerOptionCell.self)
        tableView.register(AnswerSliderCell.self)
        tableView.register(AnswerRangeCell.self)
    }
    
    private func updateNextButtonState() {
        nextButton.isEnabled = state.answer != nil
        let _ = UIViewPropertyAnimator(duration: 0.25, dampingRatio: 1.0) { [weak self] in
            guard let `self` = self else { return }
            self.nextButton.alpha = self.nextButton.isEnabled ? 1 : 0.5
        }
        .startAnimation()
    }
    
    private func updateTitleIfNeeded(_ title: String) {
        guard let text = titleLbl.text else { return }
        guard text != title else { return }
        UIView.transition(with: titleLbl, duration: 0.5, options: .transitionCrossDissolve, animations: { [weak self] in
            guard let `self` = self else { return }
            self.titleLbl.text = title
        }, completion: nil)
    }
    
    @objc func didTapNextButton(_ sender: UIButton) {
        viewModel.send(.didTapNext)
    }
}

// MARK:  Table View Delegate
extension QuestionaryViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        
        guard let question = state.question else { return 0 }
        
        switch section {
        case .question:
            return 1
        case .answer:
            
            switch question.answerDescription.type {
            case let .singleChoice(options: options):
                return options.count
            case .numberRange(_):
                return 1
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        
        guard let question = state.question else { return UITableViewCell() }
        
        switch section {
        case .question:
            
            let cell = tableView.dequeue(QuestionTextCell.self, at: indexPath)
            
            cell.configure(with: question.title)
            
            return cell
            
        case .answer:
            
            switch question.answerDescription.type {
            case let .singleChoice(options: options):
                
                let option = options[indexPath.row]
                
                let cell = tableView.dequeue(AnswerOptionCell.self, at: indexPath)
                
                cell.configure(with: option)
                
                cell.setOption(selected: isOptionSelected(option))
                
                cell.didTap = { [weak self] in
                    self?.viewModel.send(.didSelectAnswer(question, .option(option)))
                }
                
                return cell
            case let .numberRange(range: range):
                
                let cell = tableView.dequeue(AnswerRangeCell.self, at: indexPath)
                
                cell.configure(with: range)
                cell.setRange(selectedRange: selectedRange())
                
                cell.didChangeValue = { [weak self] value in
                    self?.viewModel.send(.didSelectAnswer(question, .range(value)))
                }
                
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else { return 0 }
        
        guard let question = state.question else { return 0 }
        
        switch section {
        case .question:
            
            let minimumCellHeight = QuestionTextCell.height(for: question.title, with: tableView.frame.width)
            
            let tableViewHeight = tableView.frame.height
            let answerSectionHeight = height(for: Section.answer.rawValue)
            
            let remainingHeight = tableViewHeight - answerSectionHeight
            
            return max(remainingHeight, minimumCellHeight)
        case .answer:
            
            switch question.answerDescription.type {
            case let .singleChoice(options: options):
                guard let option = options[safe: indexPath.row] else { return 0 }
                
                return AnswerOptionCell.height(for: option, with: tableView.frame.width)
            case .numberRange(_):
                
                return AnswerRangeCell.height
            }
        }
    }
    
    private func height(for section: Int) -> CGFloat {
        let sectionMargins = sectionMargin(for: section) * 2
        
        let sectionRows = 0..<tableView.numberOfRows(inSection: section)
        
        let sectionRowsTotalHeight = sectionRows
            .reduce(into: CGFloat.zero) { (result, row) in
            result += self.tableView(tableView, heightForRowAt: IndexPath(row: row, section: section))
        }
        
        return sectionMargins + sectionRowsTotalHeight
    }
    
    func sectionMargin(for section: Int) -> CGFloat {
        guard let section = Section(rawValue: section) else { return 0 }
        guard let _ = state.question else { return 0 }
        
        switch section {
        case .question:
            return 0
        case .answer:
           return 20
        }
    }
    
    func sectionMarginView() -> UIView {
        let view = UIView()
        view.backgroundColor = .elevatedDarkBackground
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int)
        -> UIView? { sectionMarginView() }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int)
        -> UIView? { sectionMarginView() }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int)
        -> CGFloat { sectionMargin(for: section) }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int)
        -> CGFloat { sectionMargin(for: section) }
}

// MARK:  Selected Answers Helpers
extension QuestionaryViewController {
    
    func isOptionSelected(_ option: String) -> Bool {
        guard case let .didSelectAnswer(_, answer) = state else { return false }
        guard case let .option(text) = answer else { return false }
        return text == option
    }
    
    func selectedRange() -> AnswerDescription.NumberRange? {
        state.answer?.range ?? state.question?.answerDescription.type.range
    }
}

// MARK:  Popup
extension QuestionaryViewController {
    
    private func showPopup(with error: Error) {
        showPopup(error.localizedDescription, icon: #imageLiteral(resourceName: "failure_circle.pdf"))
    }
    
    private func showPopup(_ message: String, icon: UIImage? = nil) {
        guard self.popup == nil else {
            
            UIView.transition(with: popup!.label, duration: 0.25, options: .transitionCrossDissolve, animations: { [weak self] in
                self?.popup?.label.text = message
            }, completion: nil)
            
            if let icon = icon {
                self.popup?.iconImageView.image = icon
                self.popup?.activityIndicator.stopAnimating()
            } else {
                self.popup?.iconImageView.image = nil
                self.popup?.activityIndicator.startAnimating()
            }
            
            return
        }
        
        let popup = PopupView()
        self.popup = popup
        popup.label.text = message
        if let icon = icon {
            popup.iconImageView.image = icon
        } else {
            popup.activityIndicator.startAnimating()
        }
        popup.alpha = 0
        view.addSubview(popup)
        popup.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
        view.layoutIfNeeded()
        
        let animator = UIViewPropertyAnimator(duration: 0.25, dampingRatio: 1) { [weak self] in
            guard let `self` = self else { return }
            self.tableView.alpha = 0
            self.nextButton.alpha = 0
            popup.alpha = 1
        }
        
        animator.startAnimation()
    }
    
    private func hidePopupIfNeeded() {
        guard let popup = popup else { return }
        popup.activityIndicator.stopAnimating()
        
        let animator = UIViewPropertyAnimator(duration: 0.1, dampingRatio: 1) { [weak self] in
            guard let `self` = self else { return }
            self.tableView.alpha = 1
            self.nextButton.alpha = 0.5
            popup.alpha = 0
        }
        
        animator.addCompletion { (_) in
            popup.removeFromSuperview()
        }
        
        animator.startAnimation()
    }
}
