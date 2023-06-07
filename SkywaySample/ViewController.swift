//
//  ViewController.swift
//  SkywaySample
//
//  Created by Shuhei Yukawa
//

import UIKit
import Combine
import SkyWayRoom

enum Section: Int {
    case votedUser = 0
}

class ViewController: UIViewController {
    private let settingStackView = UIStackView()
    private let switchStackView = UIStackView()
    private let selectSwitchLabel = UILabel()
    private let selectSwitch = UISwitch()
    private let roomNameStackView = UIStackView()
    private let roomNameLabel = UILabel()
    private let roomNameTextField = UITextField()
    
    private let collectionView: UICollectionView
    
    private let activityIndicator = UIActivityIndicatorView()
    
    private let conferenceToolBar = UIToolbar()
    private var muteButton: UIBarButtonItem?
    private var cameraButton: UIBarButtonItem?
    private var cameraPositionButton: UIBarButtonItem?
    private var speakerButton: UIBarButtonItem?
    private var connectButton: UIBarButtonItem?
    private var disconnectButton: UIBarButtonItem?
    
    private let viewModel = ViewModel()
    
    private let layout: UICollectionViewFlowLayout
    private lazy var dataSource =
    UICollectionViewDiffableDataSource<Section, ConferenceStream>(collectionView: collectionView)
    {
        collectionView, indexPath, item in
        let cell: ItemCell = collectionView.dequeueReusableCell(withReuseIdentifier: ItemCell.cellIdentifier, for: indexPath) as? ItemCell ?? ItemCell(frame: CGRect.zero)
        
        cell.setup(stream: item)
        return cell
    }
    
    private var cancelable: [AnyCancellable] = []

    required init?(coder: NSCoder) {
        self.layout = UICollectionViewFlowLayout()
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
        
        super.init(coder: coder)
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.setupComponent()
        self.setupLayout()
        
        self.bind()
    }

    private func setupComponent() {
        self.setupSettingStackView()
        
        self.setupMemberCollectionView()
        
        self.setupConferenceToolBar()
        
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.color = .gray
        self.view.addSubview(self.activityIndicator)
    }
    
    private func setupSettingStackView() {
        self.settingStackView.axis = .vertical
        self.settingStackView.spacing = 5
        self.settingStackView.alignment = .fill
        self.settingStackView.distribution = .fill
        self.view.addSubview(self.settingStackView)
        
        self.switchStackView.axis = .horizontal
        self.switchStackView.spacing = 5
        self.switchStackView.alignment = .center
        self.switchStackView.distribution = .fill
        self.settingStackView.addArrangedSubview(self.switchStackView)
        
        self.selectSwitchLabel.text = "P2PRoom/SFURoom: "
        self.switchStackView.addArrangedSubview(self.selectSwitchLabel)
        
        self.switchStackView.addArrangedSubview(self.selectSwitch)
        
        self.roomNameStackView.axis = .horizontal
        self.roomNameStackView.spacing = 5
        self.roomNameStackView.alignment = .center
        self.roomNameStackView.distribution = .fill
        self.settingStackView.addArrangedSubview(self.roomNameStackView)
        
        self.roomNameLabel.text = "Room Name: "
        self.roomNameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        self.roomNameStackView.addArrangedSubview(self.roomNameLabel)
        
        self.roomNameTextField.placeholder = "TestRoom"
        self.roomNameTextField.borderStyle = .roundedRect
        self.roomNameTextField.delegate = self
        self.roomNameStackView.addArrangedSubview(self.roomNameTextField)
    }
    
    private func setupMemberCollectionView() {
        self.layout.itemSize = CGSize(width: 150, height: 150)
        self.collectionView.register(ItemCell.self, forCellWithReuseIdentifier: ItemCell.cellIdentifier)
        self.collectionView.dataSource = self.dataSource
        self.view.addSubview(self.collectionView)
    }
    
    private func setupConferenceToolBar() {
        let muteButton = UIBarButtonItem(image: UIImage(systemName: "mic.slash.fill"), style: .plain, target: self, action: #selector(tappedMute(_:)))
        self.muteButton = muteButton
        
        let cameraButton = UIBarButtonItem(image: UIImage(systemName: "video.fill"), style: .plain, target: self, action: #selector(tappedCamera(_:)))
        self.cameraButton = cameraButton
        
        let speakerButton = UIBarButtonItem(image: UIImage(systemName: "speaker.wave.3.fill"), style: .plain, target: self, action: #selector(tappedSpeaker(_:)))
        self.speakerButton = speakerButton
        
        let cameraPositionButton = UIBarButtonItem(image: UIImage(systemName: "arrow.triangle.2.circlepath.camera.fill"), style: .plain, target: self, action: #selector(tappedCameraPosition(_:)))
        self.cameraPositionButton = cameraPositionButton
        
        let connectButton = UIBarButtonItem(image: UIImage(systemName: "phone.fill"), style: .plain, target: self, action: #selector(tappedConnect))
        connectButton.tintColor = .green
        self.connectButton = connectButton
        
        let disconnectButton = UIBarButtonItem(image: UIImage(systemName: "phone.down.fill"), style: .plain, target: self, action: #selector(tappedDisconnect))
        disconnectButton.tintColor = .red
        self.disconnectButton = disconnectButton
        
        self.conferenceToolBar.items = [.flexibleSpace(), muteButton,
                                        .fixedSpace(5), cameraButton,
                                        .fixedSpace(15), speakerButton,
                                        .fixedSpace(5), cameraPositionButton,
                                        .flexibleSpace() ,connectButton,
                                        .fixedSpace(5), disconnectButton,
                                        .flexibleSpace()]
        self.view.addSubview(self.conferenceToolBar)
    }
    
    private func setupLayout() {
        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.activityIndicator.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        self.activityIndicator.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        self.activityIndicator.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.activityIndicator.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        
        self.settingStackView.translatesAutoresizingMaskIntoConstraints = false
        self.settingStackView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        self.settingStackView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.settingStackView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        self.settingStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        self.settingStackView.bottomAnchor.constraint(equalTo: self.collectionView.topAnchor).isActive = true
        
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.topAnchor.constraint(equalTo: self.settingStackView.bottomAnchor).isActive = true
        self.collectionView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.collectionView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        self.collectionView.bottomAnchor.constraint(equalTo: self.conferenceToolBar.topAnchor).isActive = true
        
        self.conferenceToolBar.translatesAutoresizingMaskIntoConstraints = false
        self.conferenceToolBar.heightAnchor.constraint(equalToConstant: 60).isActive = true
        self.conferenceToolBar.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.conferenceToolBar.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        self.conferenceToolBar.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
    
    private func bind() {
        let cancellable1 = self.viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
            if isLoading {
                self?.activityIndicator.startAnimating()
            } else {
                self?.activityIndicator.stopAnimating()
            }
        }
        self.cancelable.append(cancellable1)
        
        let cancellable2 = self.viewModel.$alertMessage
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alertMessage in
                guard let alertMessage = alertMessage else { return }
                self?.showAlert(message: alertMessage)
        }
        self.cancelable.append(cancellable2)
        
        let cancellable3 = self.viewModel.$memberList
            .receive(on: DispatchQueue.main)
            .sink{ [weak self] items in
                guard let dataSource = self?.dataSource else { return }
                var snapshot = dataSource.snapshot()
                snapshot.deleteAllItems()
                if snapshot.sectionIdentifiers.count < 1 {
                    snapshot.appendSections([Section.votedUser])
                }
                snapshot.appendItems(items)
                dataSource.apply(snapshot)
        }
        self.cancelable.append(cancellable3)
        
        let cancellable4 = self.viewModel.$muteState
            .receive(on: DispatchQueue.main)
            .sink{ [weak self] state in
                self?.muteButton?.image = state.iconImage
        }
        self.cancelable.append(cancellable4)
        
        let cancellable5 = self.viewModel.$cameraState
            .receive(on: DispatchQueue.main)
            .sink{ [weak self] state in
                self?.cameraButton?.image = state.iconImage
        }
        self.cancelable.append(cancellable5)
        
        let cancellable6 = self.viewModel.$callState
            .receive(on: DispatchQueue.main)
            .sink{ [weak self] state in
                if state == .connected {
                    self?.disconnectButton?.isEnabled = true
                    self?.muteButton?.isEnabled = true
                    self?.cameraButton?.isEnabled = true
                    self?.cameraPositionButton?.isEnabled = true
                    self?.speakerButton?.isEnabled = true
                    self?.connectButton?.isEnabled = false
                } else {
                    self?.disconnectButton?.isEnabled = false
                    self?.muteButton?.isEnabled = false
                    self?.cameraButton?.isEnabled = false
                    self?.cameraPositionButton?.isEnabled = false
                    self?.speakerButton?.isEnabled = false
                    self?.connectButton?.isEnabled = true
                }
        }
        self.cancelable.append(cancellable6)
    }
    
    @objc
    private func tappedMute(_ button: UIBarButtonItem) {
        Task { @MainActor in
            do {
                try await self.viewModel.switchMute()
            } catch let error {
                self.showAlert(message: error.localizedDescription)
            }
        }
    }
    
    @objc
    private func tappedCamera(_ button: UIBarButtonItem) {
        Task {
            do {
                try await self.viewModel.switchCamera()
            } catch let error {
                self.showAlert(message: error.localizedDescription)
            }
        }
    }
    
    @objc
    private func tappedCameraPosition(_ button: UIBarButtonItem) {
        Task {
            do {
                try await self.viewModel.switchCameraPosition()
            } catch let error {
                self.showAlert(message: error.localizedDescription)
            }
        }
    }
    
    @objc
    private func tappedSpeaker(_ button: UIBarButtonItem) {
        Task {
            await self.viewModel.switchSpeaker()
        }
    }
    
    @objc
    private func tappedConnect() {
        let roomName = self.roomNameTextField.text ?? "TestRoom"
        Task {
            do {
                try await self.viewModel.connect(roomName: roomName, isP2P: !self.selectSwitch.isOn)
            } catch let error {
                self.showAlert(message: error.localizedDescription)
            }
        }
    }
    
    @objc
    private func tappedDisconnect() {
        Task {
            do {
                try await self.viewModel.disconnect()
            } catch let error {
                self.showAlert(message: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func showAlert(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(alertController, animated: true)
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

final class ItemCell: UICollectionViewCell {
    static let cellIdentifier = "ItemCell"
    private let nameLabel = UILabel()
    private let horizontalStackView = UIStackView()
    private let muteIcon = UIImageView()
    private let videoView = SkywayVideoView(frame: CGRect.zero)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.addSubview(self.videoView)
        
        self.horizontalStackView.axis = .horizontal
        self.horizontalStackView.spacing = 5
        self.horizontalStackView.alignment = .fill
        self.horizontalStackView.distribution = .fill
        self.contentView.addSubview(self.horizontalStackView)
        
        self.muteIcon.image = MuteState.unmute.iconImage?.withRenderingMode(.alwaysTemplate).withAlignmentRectInsets(UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10))
        self.muteIcon.tintColor = .red
        self.muteIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.muteIcon.setContentHuggingPriority(.required, for: .horizontal)
        self.muteIcon.isHidden = true
        self.horizontalStackView.addArrangedSubview(self.muteIcon)
        
        self.nameLabel.numberOfLines = 1
        self.nameLabel.textAlignment = .center
        self.nameLabel.textColor = .white
        self.nameLabel.shadowColor = .black
        self.nameLabel.shadowOffset = CGSize(width: 5, height: 5)
        self.horizontalStackView.addArrangedSubview(self.nameLabel)
        
        self.videoView.translatesAutoresizingMaskIntoConstraints = false
        self.videoView.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        self.videoView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor).isActive = true
        self.videoView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor).isActive = true
        self.videoView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        
        self.horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        self.horizontalStackView.topAnchor.constraint(equalTo: self.videoView.bottomAnchor, constant: -40).isActive = true
        self.horizontalStackView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        self.horizontalStackView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor).isActive = true
        self.horizontalStackView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor).isActive = true
        
        self.muteIcon.translatesAutoresizingMaskIntoConstraints = false
        self.muteIcon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        self.muteIcon.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(stream: ConferenceStream) {
        self.nameLabel.text = stream.userName
        
        self.videoView.setStream(stream: stream)
        
        self.muteIcon.isHidden = stream.isMute
    }
}
