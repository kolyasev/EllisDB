// ----------------------------------------------------------------------------
//
//  DatabaseObjectObserver.swift
//
//  @author Denis Kolyasev <kolyasev@gmail.com>
//
// ----------------------------------------------------------------------------

import Foundation
import YapDatabase

// ----------------------------------------------------------------------------

public class DatabaseObjectObserver<T: DatabaseObject>
{
// MARK: Construction

    init(collection: String, key: String, connection: YapDatabaseConnection)
    {
        // Init instance variables
        self.collection = collection
        self.key = key
        self.connection = connection

        // Create new long lived transaction
        self.connection.beginLongLivedReadTransaction()

        // Register for notifications
        weak var weakSelf = self
        self.notificationObserver = NSNotificationCenter.defaultCenter().addObserverForName(YapDatabaseModifiedNotification,
                object: self.connection.database, queue: nil,
                usingBlock: { notification in
                    dispatch.async.bg {
                        weakSelf?.handleDatabaseModifiedNotification(notification)
                    }
                })
    }

    deinit {
        // Unregister from notifications
        if let observer = self.notificationObserver {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
    }

// MARK: Properties

    public weak var delegate: DatabaseObjectObserverDelegate?

    public var callback: CallbackBlock?

    public var object: T?
    {
        var result: T?

        let collection = self.collection
        let key = self.key

        // Read from database
        self.connection.readWithBlock { transaction in
            result = transaction.objectForKey(key, inCollection: collection) as? T
        }

        return result
    }

// MARK: Private Functions

    private func handleDatabaseModifiedNotification(notification: NSNotification)
    {
        let notifications = self.connection.beginLongLivedReadTransaction()
        if  notifications.isEmpty { return }

        if self.connection.hasChangeForKey(self.key, inCollection: self.collection, inNotifications: notifications)
        {
            dispatch.async.main { [weak self] in
                // Notify delegate
                self?.delegate?.databaseObjectObserverDidUpdateObject()
                self?.callback?(self?.object)
            }
        }
    }

// MARK: Inner Types

    public typealias CallbackBlock = (T?) -> Void

// MARK: Variables

    private let collection: String

    private let key: String

    private let connection: YapDatabaseConnection

    private var notificationObserver: AnyObject?

}

// ----------------------------------------------------------------------------

public protocol DatabaseObjectObserverDelegate: class
{
// MARK: - Functions

    func databaseObjectObserverDidUpdateObject()

}

// ----------------------------------------------------------------------------
